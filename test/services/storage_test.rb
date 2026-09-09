require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "ostruct"
require "minitest/mock"
require_relative "../../app/services/storage/adapter"
require_relative "../../app/services/storage/local_storage"

class LocalStorageTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("banshi-storage-test-")
    @storage = Storage::LocalStorage.new(root: File.join(@directory, "objects"))
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  def test_binary_round_trip_and_idempotent_deletion
    bytes = "\x00\xFF\x89PNG\r\n".b
    key = "assets/ab/example.png"

    refute @storage.exists?(key: key)
    assert_equal key, @storage.put(key: key, bytes: bytes, content_type: "image/png")
    assert @storage.exists?(key: key)
    assert_equal bytes, @storage.read(key: key)
    assert_equal Encoding::BINARY, @storage.read(key: key).encoding
    assert @storage.delete(key: key)
    refute @storage.exists?(key: key)
    assert @storage.delete(key: key)
    assert_raises(Storage::Adapter::NotFound) { @storage.read(key: key) }
  end

  def test_replacement_never_exposes_a_partially_written_object
    key = "assets/current.bin"
    before = "A".b * 131_072
    after = "B".b * 524_288
    @storage.put(key: key, bytes: before, content_type: "application/octet-stream")

    ready = Queue.new
    stop = Queue.new
    reads = []
    reader = Thread.new do
      reads << @storage.read(key: key)
      ready << true
      loop do
        break unless stop.empty?

        reads << @storage.read(key: key)
        Thread.pass
      end
    end
    ready.pop
    8.times do |index|
      @storage.put(key: key, bytes: index.even? ? after : before,
                   content_type: "application/octet-stream")
    end
    stop << true
    reader.value

    assert reads.all? { |bytes| bytes == before || bytes == after },
           "a reader observed an incomplete replacement"
    assert_equal before, @storage.read(key: key)
    assert_equal ["current.bin"], Dir.children(File.join(@directory, "objects/assets"))
  ensure
    stop << true if stop && stop.empty?
    reader&.join
  end

  def test_all_operations_reject_path_traversal
    ["../outside", "a/../../outside", "/tmp/outside", "a/./b", "a//b",
     "a\\..\\outside", "a\x00b", "", "a/", "C:/outside"].each do |key|
      assert_raises(Storage::Adapter::InvalidKey, "put accepted #{key.inspect}") do
        @storage.put(key: key, bytes: "bad", content_type: "text/plain")
      end
      [:read, :delete, :exists?].each do |operation|
        assert_raises(Storage::Adapter::InvalidKey, "#{operation} accepted #{key.inspect}") do
          @storage.public_send(operation, key: key)
        end
      end
    end
    refute File.exist?(File.join(@directory, "outside"))
  end

  def test_symlinked_parent_or_object_cannot_escape_storage_root
    outside = File.join(@directory, "outside")
    FileUtils.mkdir_p(outside)
    secret = File.join(outside, "secret.bin")
    File.binwrite(secret, "private")
    File.symlink(outside, File.join(@directory, "objects", "linked"))
    File.symlink(secret, File.join(@directory, "objects", "object-link"))

    ["linked/secret.bin", "object-link"].each do |key|
      assert_raises(Storage::Adapter::InvalidKey) do
        @storage.put(key: key, bytes: "changed", content_type: "text/plain")
      end
      [:read, :delete, :exists?].each do |operation|
        assert_raises(Storage::Adapter::InvalidKey) { @storage.public_send(operation, key: key) }
      end
    end
    assert_equal "private", File.binread(secret)
  end
end

class S3CompatibleStorageTest < Minitest::Test
  def setup
    require "aws-sdk-s3"
    require_relative "../../app/services/storage/s3_compatible_storage"
    @config = OpenStruct.new(endpoint: "https://objects.example.test", bucket: "banshi-media",
                             region: "us-east-1", access_key: "test-access", secret_key: "test-secret")
    @client = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    @storage = Storage::S3CompatibleStorage.new(config: @config, client: @client)
  end

  def test_sdk_requests_preserve_the_object_key_bytes_and_content_type
    key = "assets/ab/image.png"
    bytes = "\x00\xFFimage".b
    @client.stub_responses(:get_object, body: bytes)

    assert_equal key, @storage.put(key: key, bytes: bytes, content_type: "image/png")
    assert_equal bytes, @storage.read(key: key)
    assert @storage.exists?(key: key)
    assert @storage.delete(key: key)

    requests = @client.api_requests
    assert_equal [:put_object, :get_object, :head_object, :delete_object],
                 requests.map { |request| request[:operation_name] }
    assert_equal({ bucket: "banshi-media", key: key, body: bytes, content_type: "image/png" },
                 requests.first[:params].slice(:bucket, :key, :body, :content_type))
    requests.drop(1).each do |request|
      assert_equal({ bucket: "banshi-media", key: key }, request[:params].slice(:bucket, :key))
    end
  end

  def test_missing_object_is_distinct_from_authorization_failure
    @client.stub_responses(:head_object, "NotFound")
    refute @storage.exists?(key: "missing.png")
    @client.stub_responses(:get_object, "NoSuchKey")
    assert_raises(Storage::Adapter::NotFound) { @storage.read(key: "missing.png") }

    @client.stub_responses(:head_object, "AccessDenied")
    assert_raises(Aws::S3::Errors::AccessDenied) { @storage.exists?(key: "private.png") }
    @client.stub_responses(:get_object, "AccessDenied")
    assert_raises(Aws::S3::Errors::AccessDenied) { @storage.read(key: "private.png") }
    @client.stub_responses(:delete_object, "AccessDenied")
    assert_raises(Aws::S3::Errors::AccessDenied) { @storage.delete(key: "private.png") }
  end

  def test_s3_rejects_unsafe_keys_before_sending_a_request
    assert_raises(Storage::Adapter::InvalidKey) do
      @storage.put(key: "../outside", bytes: "bad", content_type: "text/plain")
    end
    [:read, :delete, :exists?].each do |operation|
      assert_raises(Storage::Adapter::InvalidKey) { @storage.public_send(operation, key: "../outside") }
    end
    assert_empty @client.api_requests
  end

  def test_configured_client_uses_the_endpoint_path_style_and_verified_tls
    original_constructor = Aws::S3::Client.method(:new)
    client = nil
    constructor = lambda do |options|
      client = original_constructor.call(**options, stub_responses: true)
    end
    Aws::S3::Client.stub(:new, constructor) do
      storage = Storage::S3CompatibleStorage.new(config: @config)
      storage.exists?(key: "image.png")
    end

    request = client.api_requests.first[:context].http_request
    assert_equal "https://objects.example.test/banshi-media/image.png", request.endpoint.to_s
    assert client.config.ssl_verify_peer
    assert_equal "test-access", client.config.credentials.credentials.access_key_id
  end

  def test_rejects_endpoint_urls_with_embedded_credentials_or_non_http_schemes
    ["file:///tmp/objects", "https://user:password@example.test", "https://example.test?token=secret"].each do |endpoint|
      @config.endpoint = endpoint
      assert_raises(ArgumentError) { Storage::S3CompatibleStorage.new(config: @config) }
    end
  end
end
