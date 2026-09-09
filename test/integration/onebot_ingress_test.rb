require_relative '../domain_helpers'

class OnebotIngressTest < ActionDispatch::IntegrationTest
  include DomainHelpers
  include ActiveJob::TestHelper

  setup do
    @group=domain_group
    @connection=domain_bot(@group)
    @payload={'self_id'=>@connection.bot_account.external_id,'post_type'=>'message','message_type'=>'group',
      'group_id'=>@group.external_id,'user_id'=>'fictional-member','message_id'=>'ingress-message','time'=>Time.current.to_i,
      'message'=>[{'type'=>'text','data'=>{'text'=>'ordinary conversation'}}]}
  end

  test 'ingress authenticates and checks the receiving bot before persistence' do
    post onebot_events_path(@connection),params:@payload,as: :json
    assert_response :not_found
    AppConfig.with(napcat:{enabled:true,access_token:'api-test',webhook_token:'ingress-test'}) do
      assert_no_difference('RawEvent.count') do
        post onebot_events_path(@connection),params:@payload,as: :json
        assert_response :unauthorized
        post onebot_events_path(@connection),params:@payload.merge('self_id'=>'different-bot'),headers:{'Authorization'=>'Bearer ingress-test'},as: :json
        assert_response :bad_request
      end
    end
  end

  test 'accepted webhook is durable queued and idempotent without doing collection in HTTP' do
    AppConfig.with(napcat:{enabled:true,access_token:'api-test',webhook_token:'ingress-test'}) do
      assert_no_difference('Message.count') do
        assert_difference('InternalEvent.count',1) do
          2.times do
            assert_enqueued_with(job:EventProcessJob) do
              post onebot_events_path(@connection),params:@payload,headers:{'Authorization'=>'Bearer ingress-test'},as: :json
              assert_response :accepted
            end
          end
        end
      end
      assert_equal 1,RawEvent.where(bot_connection:@connection).count
    end
  end
end
