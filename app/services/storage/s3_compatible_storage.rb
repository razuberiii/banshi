require "aws-sdk-s3"
require "uri"
require_relative "adapter"

module Storage
  class S3CompatibleStorage < Adapter
    def initialize(config: AppConfig.storage, client: nil)
      @bucket = config.bucket
      raise ArgumentError, "S3 storage requires a bucket" if @bucket.to_s.empty?

      @client = client || build_client(config)
    end

    def put(key:, bytes:, content_type:)
      validate_key!(key)
      raise ArgumentError, "bytes must be a String" unless bytes.is_a?(String)

      @client.put_object(bucket: @bucket, key: key, body: bytes, content_type: content_type)
      key
    end

    def read(key:)
      validate_key!(key)
      @client.get_object(bucket: @bucket, key: key).body.read.b
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      raise NotFound, "Stored object not found"
    end

    def delete(key:)
      validate_key!(key)
      @client.delete_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      true
    end

    def exists?(key:)
      validate_key!(key)
      @client.head_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      false
    end

    private

    def build_client(config)
      options = {
        region: config.region,
        credentials: Aws::Credentials.new(config.access_key, config.secret_key),
        force_path_style: true,
        ssl_verify_peer: true,
        ignore_configured_endpoint_urls: true
      }
      unless config.endpoint.to_s.empty?
        endpoint = URI.parse(config.endpoint)
        unless %w[http https].include?(endpoint.scheme) && endpoint.host &&
               !endpoint.userinfo && !endpoint.query && !endpoint.fragment
          raise ArgumentError, "S3 endpoint must be an HTTP(S) URL without embedded credentials, query, or fragment"
        end
        options[:endpoint] = endpoint.to_s
      end
      Aws::S3::Client.new(options)
    rescue URI::InvalidURIError
      raise ArgumentError, "S3 endpoint is not a valid URL"
    end
  end
end
