require 'minitest/autorun'
require_relative '../../app/services/media/forward_structure'

class ForwardStructureTest < Minitest::Test
  AssetValue=Struct.new(:id,:sha256)
  AttachmentValue=Struct.new(:asset)
  class Attachments
    def initialize(assets) = @assets=assets
    def find_by!(position:) = AttachmentValue.new(@assets.fetch(position))
  end
  ContentValue=Struct.new(:metadata,:attachments)

  def test_fingerprint_includes_nested_structure_and_image_placement
    assets=[AssetValue.new(1,'a'*64),AssetValue.new(2,'b'*64)]
    a=[{'segments'=>[{'type'=>'text','text'=>'outer'},{'type'=>'forward','nodes'=>[{'segments'=>[{'type'=>'image','attachment_position'=>0},{'type'=>'image','attachment_position'=>1}]}]}]}]
    b=[{'segments'=>[{'type'=>'text','text'=>'outer'},{'type'=>'image','attachment_position'=>0},{'type'=>'forward','nodes'=>[{'segments'=>[{'type'=>'image','attachment_position'=>1}]}]}]}]
    refute_equal Media::ForwardStructure.fingerprint(a,assets:assets),Media::ForwardStructure.fingerprint(b,assets:assets)
  end

  def test_serialization_retains_every_image_and_uses_current_attachment_replacements
    assets=[AssetValue.new(1,'a'*64),AssetValue.new(2,'b'*64)]
    tree=[{'segments'=>[{'type'=>'text','text'=>'outer'},{'type'=>'forward','nodes'=>[{'segments'=>[{'type'=>'image','attachment_position'=>0},{'type'=>'image','attachment_position'=>1}]}]}]}]
    content=ContentValue.new({'forward_tree'=>tree},Attachments.new(assets))
    received=Media::ForwardStructure.onebot_nodes(content) { |asset|{'file'=>"fake://#{asset.id}"} }
    images=received.first.fetch('content').last.dig('data','content').first.fetch('content')
    assert_equal ['fake://1','fake://2'],images.map { |image|image.dig('data','file') }
    assets[0]=AssetValue.new(3,'c'*64)
    sent=Media::ForwardStructure.onebot_nodes(content,bot_external_id:'bot') { |asset|{'file'=>"safe://#{asset.id}"} }
    serialized=JSON.generate(sent)
    assert_includes serialized,'safe://3'
    assert_includes serialized,'safe://2'
    refute_includes serialized,'safe://1'
    assert_node_only_when_nested(sent)
  end

  def assert_node_only_when_nested(segments)
    if segments.any? { |segment|segment['type']=='node' }
      assert segments.all? { |segment|segment['type']=='node' },'NapCat node arrays must not mix ordinary segments'
    end
    segments.select { |segment|segment['type']=='node' }.each { |segment|assert_node_only_when_nested(segment.dig('data','content')) }
  end
end
