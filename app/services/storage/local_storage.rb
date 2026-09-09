require "fileutils"
require "tempfile"
require_relative "adapter"

module Storage
  class LocalStorage < Adapter
    def initialize(root: Rails.root.join(AppConfig.storage.local_root))
      FileUtils.mkdir_p(root, mode: 0o700)
      @root = File.realpath(root)
    end

    def put(key:, bytes:, content_type:)
      raise ArgumentError, "bytes must be a String" unless bytes.is_a?(String)

      path = path_for(key)
      directory = File.dirname(path)
      FileUtils.mkdir_p(directory, mode: 0o700)
      path_for(key)
      # Tempfile uses exclusive creation and mode 0600. Renaming within the
      # target directory replaces an object atomically for concurrent readers.
      Tempfile.create([".upload-", ".tmp"], directory, binmode: true) do |file|
        file.write(bytes)
        file.flush
        file.fsync
        path_for(key)
        File.rename(file.path, path)
      end
      key
    end

    def read(key:)
      File.binread(path_for(key))
    rescue Errno::ENOENT
      raise NotFound, "Stored object not found"
    end

    def delete(key:)
      File.unlink(path_for(key))
      true
    rescue Errno::ENOENT
      true
    end

    def exists?(key:)
      File.file?(path_for(key))
    end

    private

    def path_for(key)
      validate_key!(key)
      path = @root
      key.split("/").each do |part|
        path = File.join(path, part)
        raise InvalidKey, "Object keys cannot traverse symbolic links" if File.symlink?(path)
      end
      path
    end
  end
end
