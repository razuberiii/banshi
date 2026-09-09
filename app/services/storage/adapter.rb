module Storage
  # Adapters return the key on put, bytes on read, and true on an idempotent
  # delete. Missing objects raise NotFound; authentication and I/O errors
  # propagate so callers cannot mistake a storage outage for missing media.
  class Adapter
    class InvalidKey < ArgumentError; end
    class NotFound < StandardError; end

    def put(key:, bytes:, content_type:)
      raise NotImplementedError
    end

    def read(key:)
      raise NotImplementedError
    end

    def delete(key:)
      raise NotImplementedError
    end

    def exists?(key:)
      raise NotImplementedError
    end

    protected

    def validate_key!(key)
      valid = key.is_a?(String) && key.valid_encoding? && key.bytesize.between?(1, 1024) &&
              !key.start_with?("/") && !key.match?(/[\\\x00-\x1f\x7f]/) &&
              !key.match?(/\A[A-Za-z]:/) &&
              key.split("/", -1).none? { |part| part.empty? || part == "." || part == ".." }
      raise InvalidKey, "Object key must be a safe relative path" unless valid

      key
    end
  end
end
