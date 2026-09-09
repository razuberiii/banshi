require 'test_helper'
class NativeMediaTest < ActiveSupport::TestCase
  test 'HTML5 parsing and libvips can coexist in the Rails process' do
    assert_equal '馆藏',Nokogiri::HTML5('<p>馆藏</p>').css('p').text
    bytes=Vips::Image.black(12,12).write_to_buffer('.png')
    assert_equal 16,Media::PerceptualHash.call(bytes).length
  end
end
