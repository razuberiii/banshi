require "minitest/autorun"
require "vips"
require_relative "../../app/services/media/perceptual_hash"

class PerceptualHashTest < Minitest::Test
  def test_distance_counts_all_64_bits_and_accepts_uppercase_hex
    assert_equal 0, Media::PerceptualHash.distance("0123456789abcdef", "0123456789ABCDEF")
    assert_equal 64, Media::PerceptualHash.distance("0000000000000000", "ffffffffffffffff")
    assert_equal 4, Media::PerceptualHash.distance("0000000000000000", "8000000000000007")
    assert_equal 2, Media::PerceptualHash.distance("8000000000000000", "0000000000000001")
  end

  def test_distance_rejects_malformed_or_truncated_hashes
    [nil, 0, "", "1234", "g" * 16, "0" * 17, "0" * 16 + "\n"].each do |bad_hash|
      assert_raises(ArgumentError) { Media::PerceptualHash.distance(bad_hash, "0" * 16) }
      assert_raises(ArgumentError) { Media::PerceptualHash.distance("0" * 16, bad_hash) }
    end
  end

  def test_low_frequency_dct_signature_has_a_known_64_bit_hash
    # The inverse cosine fixture has positive DC, then alternating negative
    # and positive low-frequency coefficients: binary 1010... = 0xaaaa....
    pixels = Array.new(32 * 32) do |index|
      x = index % 32
      y = index / 32
      value = 128.0
      (1...64).each do |frequency|
        u = frequency % 8
        v = frequency / 8
        sign = frequency.even? ? 1 : -1
        value += sign * Math.cos(Math::PI * (x + 0.5) * u / 32) *
                 Math.cos(Math::PI * (y + 0.5) * v / 32)
      end
      value.round
    end
    fixture = Vips::Image.new_from_memory(pixels.pack("C*"), 32, 32, 1, :uchar)

    assert_equal "aaaaaaaaaaaaaaaa", Media::PerceptualHash.call(fixture.write_to_buffer(".png"))
  end

  def test_resize_jpeg_and_brightness_perturbations_stay_close
    original = picture
    base_hash = Media::PerceptualHash.call(original.write_to_buffer(".png"))
    variants = {
      resized: original.resize(0.53),
      brightness: (original * 0.85 + 18).cast(:uchar)
    }
    variants.each do |name, variant|
      hash = Media::PerceptualHash.call(variant.write_to_buffer(".png"))
      assert_operator Media::PerceptualHash.distance(base_hash, hash), :<=, 8, name.to_s
    end
    jpeg_hash = Media::PerceptualHash.call(original.write_to_buffer(".jpg", Q: 35))
    assert_operator Media::PerceptualHash.distance(base_hash, jpeg_hash), :<=, 8

    other_hash = Media::PerceptualHash.call(picture(unrelated: true).write_to_buffer(".png"))
    assert_operator Media::PerceptualHash.distance(base_hash, other_hash), :>=, 18
  end

  def test_transparent_pixels_are_composited_against_white
    image = picture
    transparent = image.bandjoin(Vips::Image.black(image.width, image.height)).copy(interpretation: :b_w)
    white = Vips::Image.black(image.width, image.height).new_from_image(255)

    assert_equal Media::PerceptualHash.call(white.write_to_buffer(".png")),
                 Media::PerceptualHash.call(transparent.write_to_buffer(".png"))
  end

  def test_invalid_image_data_is_reported_as_invalid_image
    ["", "not an image", nil].each do |bytes|
      assert_raises(Media::PerceptualHash::InvalidImage) { Media::PerceptualHash.call(bytes) }
    end
  end

  private

  def picture(unrelated: false)
    width = 160
    height = 120
    pixels = Array.new(width * height) do |index|
      x = index % width
      y = index / width
      value = if unrelated
        115 + 42 * Math.sin(x / 17.0 + y / 13.0) +
          30 * Math.cos(y / 11.0) + (x > 93 && y < 48 ? 45 : -10)
      else
        35 + x * 0.45 + y * 0.2 + 11 * Math.sin((x + y) / 15.0) +
          ((x - 47)**2 + (y - 39)**2 < 27**2 ? 100 : 0) +
          (x > 89 && x < 132 && y > 61 && y < 102 ? 60 : 0)
      end
      value.round.clamp(0, 255)
    end
    Vips::Image.new_from_memory(pixels.pack("C*"), width, height, 1, :uchar)
  end
end
