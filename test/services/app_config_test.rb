require 'test_helper'
class AppConfigTest < ActiveSupport::TestCase
  test 'types defaults and units are centralized' do
    c=AppConfig.load({'CANDIDATE_TTL_MINUTES'=>'7','FEATURE_PHASH'=>'off','REPUTATION_NATURAL_WEIGHT'=>'0.25','SAFETY_SOURCE_BLACKLIST'=>'g1,g2'})
    assert_equal 420,c.candidate.ttl
    assert_equal false,c.features.phash
    assert_equal 0.25,c.reputation.natural_weight
    assert_equal %w[g1 g2],c.safety.source_blacklist
    assert_equal 'RED',c.safety.default_level
  end
  test 'invalid configuration fails before boot' do
    [{'CANDIDATE_TTL_MINUTES'=>'-1'},{'FEATURE_PHASH'=>'maybe'},{'TRIAL_GROUP_MIN'=>'6','TRIAL_GROUP_MAX'=>'3'},
      {'DUPLICATE_PHASH_THRESHOLD'=>'65'},{'SAFETY_DEFAULT_LEVEL'=>'BLUE'},{'REPUTATION_PRIOR_SUCCESSES'=>'0'},
      {'TRIAL_POSITIVE_THRESHOLD'=>'1.1'},{'REPUTATION_NATURAL_WEIGHT'=>'NaN'},{'STORAGE_PROVIDER'=>'unknown'},
      {'NAPCAT_ENABLED'=>'true'},{'RAILS_ENV'=>'production'}].each do |values|
      assert_raises(AppConfig::Invalid,values.inspect) { AppConfig.load(values) }
    end
  end
  test 'overrides are scoped and restored on exceptions' do
    before=AppConfig.candidate.ttl
    assert_raises(RuntimeError) { AppConfig.with(candidate:{ttl:42}) { assert_equal 42,AppConfig.candidate.ttl;raise 'expected' } }
    assert_equal before,AppConfig.candidate.ttl
  end
  test 'bot card parsing is a central extensible rule with safe unknown fallback' do
    assert_equal({collect:true,distribute:false},BotModeParser.call('搬💩'))
    assert_equal({collect:false,distribute:true},BotModeParser.call('吃💩'))
    assert_equal({collect:true,distribute:true},BotModeParser.call('自助餐 · 值班中'))
    assert_equal({collect:false,distribute:false},BotModeParser.call('休息'))
  end

  test 'multiple connections resolve separate credentials without database secrets' do
    c=AppConfig.load({'NAPCAT_ENABLED'=>'true','NAPCAT_WEBHOOK_TOKEN'=>'ingress-test','NAPCAT_CONNECTION_TOKENS'=>'{"bot-a":"a-token","bot-b":"b-token"}'})
    assert_equal 'a-token',c.napcat.connection_tokens['bot-a']
    AppConfig.with(napcat:{connection_tokens:c.napcat.connection_tokens,access_token:'fallback-token'}) do
      assert_equal 'a-token',BotConnection.new(credential_env_key:'bot-a').access_token
      assert_equal 'b-token',BotConnection.new(credential_env_key:'bot-b').access_token
      assert_equal 'fallback-token',BotConnection.new.access_token
    end
    assert_raises(AppConfig::Invalid) { AppConfig.load({'NAPCAT_CONNECTION_TOKENS'=>'{"bot-a":42}'}) }
  end
end
