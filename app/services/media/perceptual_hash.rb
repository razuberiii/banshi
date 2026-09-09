require "vips"

module Media
  # DCT-II pHash, version 1: 32x32 luminance, row-major 8x8 coefficients,
  # median of the 63 AC coefficients, then 64 high-to-low bits. Store hashes
  # as hex strings: an unsigned 64-bit value does not fit a signed bigint.
  class PerceptualHash
    class InvalidImage < ArgumentError; end

    SAMPLE_SIZE = 32
    HASH_SIZE = 8
    MAX_INPUT_BYTES = 25 * 1024 * 1024
    MAX_PIXELS = 40_000_000
    HEX_PATTERN = /\A[0-9a-fA-F]{16}\z/
    COSINES = Array.new(HASH_SIZE) do |frequency|
      scale = frequency.zero? ? Math.sqrt(1.0 / SAMPLE_SIZE) : Math.sqrt(2.0 / SAMPLE_SIZE)
      Array.new(SAMPLE_SIZE) do |position|
        scale * Math.cos(Math::PI * (position + 0.5) * frequency / SAMPLE_SIZE)
      end.freeze
    end.freeze

    def self.call(bytes)
      unless bytes.is_a?(String) && bytes.bytesize.between?(1, MAX_INPUT_BYTES)
        raise InvalidImage, "Image bytes are empty or exceed the hashing limit"
      end

      image = Vips::Image.new_from_buffer(bytes, "", access: :sequential, fail_on: :error)
      if image.width * image.height > MAX_PIXELS
        raise InvalidImage, "Image dimensions exceed the hashing limit"
      end

      image = image.autorot.colourspace(:srgb)
      image = image.flatten(background: [255, 255, 255]) if image.has_alpha?
      image = image.colourspace(:b_w)
      image = image.resize(SAMPLE_SIZE.to_f / image.width,
                           vscale: SAMPLE_SIZE.to_f / image.height, kernel: :lanczos3)
      pixels = image.cast(:double).write_to_memory.unpack("d*").each_slice(SAMPLE_SIZE).to_a
      coefficients = dct(pixels)
      median = coefficients.drop(1).sort[31]
      value = coefficients.reduce(0) { |bits, coefficient| (bits << 1) | (coefficient > median ? 1 : 0) }
      format("%016x", value)
    rescue Vips::Error
      raise InvalidImage, "Image could not be decoded for perceptual hashing"
    end

    def self.distance(left, right)
      unless [left, right].all? { |value| value.is_a?(String) && HEX_PATTERN.match?(value) }
        raise ArgumentError, "Perceptual hashes must contain exactly 16 hexadecimal characters"
      end

      difference = left.to_i(16) ^ right.to_i(16)
      count = 0
      until difference.zero?
        difference &= difference - 1
        count += 1
      end
      count
    end

    def self.dct(pixels)
      # A separable orthonormal DCT calculates only the 8x8 frequencies used
      # by the hash; all image-size work stays in libvips' demand-driven path.
      horizontal = pixels.map do |row|
        COSINES.map { |basis| row.each_index.sum { |x| row[x] * basis[x] } }
      end
      Array.new(HASH_SIZE * HASH_SIZE) do |index|
        u = index % HASH_SIZE
        v = index / HASH_SIZE
        coefficient = SAMPLE_SIZE.times.sum { |y| horizontal[y][u] * COSINES[v][y] }
        # Round-off around zero must not give flat images arbitrary bits.
        coefficient.abs < 1e-8 ? 0.0 : coefficient
      end
    end
    private_class_method :dct
  end
end
