require_relative '../domain_helpers'

class ForwardIngestionTest < ActiveSupport::TestCase
  include DomainHelpers

  def asset
    sha=Digest::SHA256.hexdigest(SecureRandom.hex(10))
    Asset.create!(sha256:sha,storage_key:"test/#{sha}.png",content_type:'image/png',byte_size:8,width:2,height:2)
  end

  def ingest(segments, adapter:)
    payload={'post_type'=>'message','message_type'=>'group','group_id'=>'g','user_id'=>'p','message_id'=>'m','time'=>Time.current.to_i,'message'=>segments}
    envelope=Events::Normalizer.call(payload,bot_external_id:'bot').first
    Media::ContentIngestor.call(event:envelope,adapter:adapter)
  end

  test 'mixed top-level material and nested multi-image forwards survive fake round trip' do
    group=domain_group
    adapter=Adapters::FakeNapCatAdapter.new(domain_bot(group))
    first=asset
    second=asset
    nested=[{'content'=>[{'type'=>'image','data'=>{'file'=>"fake://#{first.id}"}},{'type'=>'text','data'=>{'text'=>'between'}},{'type'=>'image','data'=>{'file'=>"fake://#{second.id}"}}]}]
    nodes=[{'content'=>[{'type'=>'text','data'=>{'text'=>'outer'}},{'type'=>'forward','data'=>{'content'=>nested}}]}]
    content=ingest([{'type'=>'text','data'=>{'text'=>'caption'}},{'type'=>'forward','data'=>{'content'=>nodes}},{'type'=>'image','data'=>{'file'=>"fake://#{second.id}"}}],adapter:adapter)
    assert_equal [first.id,second.id,second.id],content.assets.pluck(:id)
    assert_equal 1,content.forward_nodes.where.not(parent_id:nil).count
    assert content.metadata.fetch('forward_tree').any?
    round_trip=ingest([{'type'=>'forward','data'=>{'id'=>"fake-forward-#{content.id}"}}],adapter:adapter)
    assert_equal content.fingerprint,round_trip.fingerprint
    assert_equal content.assets.pluck(:id),round_trip.assets.pluck(:id)
  end

  test 'direct model forward children and assets are preserved by fake adapter' do
    group=domain_group
    adapter=Adapters::FakeNapCatAdapter.new(domain_bot(group))
    image=asset
    source=domain_content(kind:'forward')
    source.attachments.create!(asset:image,position:0)
    parent=source.forward_nodes.create!(position:0,body:'parent')
    source.forward_nodes.create!(position:1,parent:parent,body:'child',asset:image)
    received=ingest([{'type'=>'forward','data'=>{'id'=>"fake-forward-#{source.id}"}}],adapter:adapter)
    assert_equal [image.id],received.assets.pluck(:id)
    assert_equal %w[parent child],received.forward_nodes.order(:position).pluck(:body)
    assert_equal 1,received.forward_nodes.where.not(parent_id:nil).count
  end

  test 'node associations affect fingerprint and recursive limits reject incomplete content' do
    group=domain_group
    adapter=Adapters::FakeNapCatAdapter.new(domain_bot(group))
    image=asset
    image_segment={'type'=>'image','data'=>{'file'=>"fake://#{image.id}"}}
    first=[{'content'=>[{'type'=>'text','data'=>{'text'=>'a'}},image_segment]},{'content'=>[{'type'=>'text','data'=>{'text'=>'b'}}]}]
    second=[{'content'=>[{'type'=>'text','data'=>{'text'=>'a'}}]},{'content'=>[{'type'=>'text','data'=>{'text'=>'b'}},image_segment]}]
    a=ingest([{'type'=>'forward','data'=>{'content'=>first}}],adapter:adapter)
    b=ingest([{'type'=>'forward','data'=>{'content'=>second}}],adapter:adapter)
    refute_equal a.fingerprint,b.fingerprint
    AppConfig.with(napcat:{max_forward_nodes:1}) do
      assert_raises(ArgumentError) { ingest([{'type'=>'forward','data'=>{'content'=>first}}],adapter:adapter) }
    end
    recursive=[{'content'=>[{'type'=>'forward','data'=>{'id'=>'cycle'}}]}]
    adapter.stub(:get_forward,recursive) do
      assert_raises(ArgumentError) { ingest([{'type'=>'forward','data'=>{'id'=>'cycle'}}],adapter:adapter) }
    end
  end

  test 'simple existing image and text-forward fingerprints retain compatibility' do
    group=domain_group
    adapter=Adapters::FakeNapCatAdapter.new(domain_bot(group))
    image=asset
    stored=ingest([{'type'=>'image','data'=>{'file'=>"fake://#{image.id}"}}],adapter:adapter)
    assert_equal Digest::SHA256.hexdigest(JSON.generate(['image',[image.sha256],[]])),stored.fingerprint
    nodes=%w[first second].map { |line|{'content'=>[{'type'=>'text','data'=>{'text'=>line}}]} }
    stored=ingest([{'type'=>'forward','data'=>{'content'=>nodes}}],adapter:adapter)
    assert_equal Digest::SHA256.hexdigest(JSON.generate(['forward',[],%w[first second]])),stored.fingerprint
  end
end
