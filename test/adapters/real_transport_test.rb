require 'minitest/autorun'
require 'minitest/mock'
require 'ostruct'
require_relative '../../config/app_config'
require_relative '../../app/services/adapters/one_bot_adapter'
require_relative '../../app/services/adapters/real_nap_cat_adapter'

class RealTransportTest < Minitest::Test
  def with_response(code,body)
    response=Net::HTTPResponse::CODE_TO_OBJ.fetch(code).new('1.1',code,'test')
    response.instance_variable_set(:@read,true)
    response.body=body
    http=Object.new
    http.define_singleton_method(:request) { |_request|response }
    transport=->(*_args,**_options,&block) { block.call(http) }
    AppConfig.with(napcat:{enabled:true,access_token:'test-access',webhook_token:'test-webhook'}) do
      Net::HTTP.stub(:start,transport) { yield }
    end
  end

  def send_entry
    endpoint=+'http://napcat.invalid/'
    endpoint.define_singleton_method(:presence) { self }
    connection=OpenStruct.new(endpoint:endpoint,bot_account:OpenStruct.new(external_id:'bot'))
    content=OpenStruct.new(assets:[],forward?:false)
    entry=OpenStruct.new(sid:'S-1',display_title:'Test',content:content)
    Adapters::RealNapCatAdapter.new(connection).send_content(group:OpenStruct.new(external_id:'group'),entry:entry,kind:'BOT_DISTRIBUTION',idempotency_key:'test-send')
  end

  def test_success_with_missing_receipt_is_ambiguous
    with_response('200','{"status":"ok","retcode":0,"data":{}}') do
      assert_raises(Adapters::OneBotAdapter::AmbiguousDelivery) { send_entry }
    end
  end

  def test_truncated_success_and_gateway_failure_are_ambiguous
    [['200','{"status":'],['502','upstream disconnected']].each do |code,body|
      with_response(code,body) do
        assert_raises(Adapters::OneBotAdapter::AmbiguousDelivery) { send_entry }
      end
    end
  end

  def test_explicit_rejection_stays_retryable_and_valid_receipt_is_returned
    with_response('200','{"status":"failed","retcode":1400,"data":null}') do
      assert_raises(Adapters::OneBotAdapter::RemoteError) { send_entry }
    end
    with_response('200','{"status":"ok","retcode":0,"data":{"message_id":123}}') do
      assert_equal '123',send_entry
    end
  end
end
