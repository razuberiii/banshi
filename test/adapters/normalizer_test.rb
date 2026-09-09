require 'minitest/autorun'
require_relative '../../app/services/events/normalizer'
class NormalizerTest < Minitest::Test
  def message_payload
    {'post_type'=>'message','message_type'=>'group','group_id'=>11,'user_id'=>22,'message_id'=>33,'self_id'=>99,'time'=>1000,'message'=>[{'type'=>'image','data'=>{'url'=>'https://gchat.qpic.cn/example'}}]}
  end
  def test_messages_are_typed_with_ids_independent_of_bot_connection
    a=Events::Normalizer.call(message_payload, bot_external_id:'99').first
    b=Events::Normalizer.call(message_payload.merge('self_id'=>100), bot_external_id:'100').first
    assert_equal 'ImageMessageReceived',a.event_type
    assert_equal a.event_id,b.event_id
    assert_equal '11',a.group_external_id
    assert_equal 'image',a.content_type
  end
  def test_reply_and_at_are_extracted_without_semantic_scoring
    e=message_payload.merge('message'=>[{'type'=>'reply','data'=>{'id'=>9}},{'type'=>'at','data'=>{'qq'=>99}},{'type'=>'text','data'=>{'text'=>' CLAIM-ABCD1234'}}])
    a=Events::Normalizer.call(e,bot_external_id:'99').first
    assert_equal '9',a.reply_to_message_id
    assert_equal Digest::SHA256.hexdigest('CLAIM-ABCD1234'),a.metadata['claim_digest']
    refute_includes JSON.generate(a.to_h), 'CLAIM-ABCD1234'
    assert_equal true,a.metadata['mentions_bot']
  end
  def test_mentions_survive_a_different_receiving_bot
    payload=message_payload.merge('message'=>[{'type'=>'at','data'=>{'qq'=>100}},{'type'=>'text','data'=>{'text'=>'CLAIM-ABCD1234'}}])
    a=Events::Normalizer.call(payload,bot_external_id:'99').first
    assert_equal ['100'],a.metadata['mentioned_external_ids']
    assert_equal Digest::SHA256.hexdigest('CLAIM-ABCD1234'),a.metadata['claim_digest']
  end
  def test_mixed_forward_references_preserve_order_and_inline_nodes
    inline=[{'content'=>[{'type'=>'text','data'=>{'text'=>'nested'}}]}]
    payload=message_payload.merge('message'=>[{'type'=>'text','data'=>{'text'=>'caption'}},{'type'=>'forward','data'=>{'id'=>'x','content'=>inline}},{'type'=>'image','data'=>{'file'=>'fake://1'}}])
    event=Events::Normalizer.call(payload,bot_external_id:'99').first
    assert_equal 'forward',event.content_type
    assert_equal %w[text forward image],event.media_references.map { |ref|ref['type'] }
    assert_equal inline,event.media_references[1]['nodes']
  end
  def test_claim_text_split_across_segments_is_redacted_before_raw_storage
    payload=message_payload.merge('message'=>[{'type'=>'text','data'=>{'text'=>'CLAIM-AB'}},{'type'=>'text','data'=>{'text'=>'CD1234'}}])
    sanitized=Events::Normalizer.redact(payload)
    combined=sanitized.fetch('message').map { |segment|segment.dig('data','text') }.join
    refute_includes combined,'CLAIM-ABCD1234'
    event=Events::Normalizer.call(payload,bot_external_id:'99').first
    assert_equal Digest::SHA256.hexdigest('CLAIM-ABCD1234'),event.metadata['claim_digest']
  end
  def test_actorless_or_legacy_reaction_is_unknown_not_a_vote
    e={'post_type'=>'notice','notice_type'=>'group_msg_emoji_like','group_id'=>11,'message_id'=>33,'time'=>1000,'likes'=>[{'emoji_id'=>'128169','count'=>10}]}
    a=Events::Normalizer.call(e,bot_external_id:'99').first
    assert_equal 'UnsupportedEvent',a.event_type
    refute a.metadata.key?('reaction')
  end
  def test_remove_is_preserved_as_explicit_inactive
    e={'post_type'=>'notice','notice_type'=>'group_msg_emoji_like','group_id'=>11,'user_id'=>22,'message_id'=>33,'time'=>1000,'is_add'=>false,'likes'=>[{'emoji_id'=>'128169','count'=>3}]}
    a=Events::Normalizer.call(e,bot_external_id:'99').first
    assert_equal 'ReactionReceived',a.event_type
    assert_equal false,a.metadata['active']
    assert_equal '128169',a.metadata['emoji_id']
  end
end
