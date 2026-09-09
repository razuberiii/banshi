require_relative "local_storage"
require_relative "s3_compatible_storage"

module Storage
  module Registry
    def self.current
      # Resolve per call: AppConfig supports scoped overrides, and credentials
      # or a provider can change without leaving a stale adapter cached.
      case AppConfig.storage.provider
      when "local" then LocalStorage.new
      when "s3" then S3CompatibleStorage.new
      else
        raise ArgumentError, "Unsupported storage provider"
      end
    end
  end
end
