module Adapters
  class OneBotAdapter
    class AmbiguousDelivery < StandardError; end
    class RemoteError < StandardError; end
    def get_group_info(group_external_id:) = raise NotImplementedError
    def get_group_member_info(group_external_id:, user_external_id:) = raise NotImplementedError
    def get_bot_card(group_external_id:) = raise NotImplementedError
    def get_forward(forward_id:) = raise NotImplementedError
    def get_message(message_external_id:) = raise NotImplementedError
    def send_content(group:, entry:, kind:, idempotency_key:) = raise NotImplementedError
    def set_bot_card(group:, card:) = raise NotImplementedError
  end
end
