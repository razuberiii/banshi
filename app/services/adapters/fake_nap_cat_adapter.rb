module Adapters
  class FakeNapCatAdapter < OneBotAdapter
    def initialize(connection) = @connection = connection
    def get_group_info(group_external_id:)
      group=Group.find_by!(external_id:group_external_id)
      { 'group_id'=>group.external_id,'group_name'=>group.public_name,'member_count'=>group.group_members.count }
    end
    def get_group_member_info(group_external_id:, user_external_id:)
      group=Group.find_by!(external_id:group_external_id)
      if user_external_id.to_s==@connection.bot_account.external_id
        membership=group.group_bot_memberships.find_by!(bot_account:@connection.bot_account,active:true)
        return {'role'=>'member','card'=>membership.card}
      end
      member=group.group_members.joins(:transporter).find_by!(transporters:{external_id:user_external_id},active:true)
      {'role'=>member.role,'card'=>member.display_name,'user_id'=>user_external_id.to_s}
    end
    def get_bot_card(group_external_id:) = get_group_member_info(group_external_id:group_external_id,user_external_id:@connection.bot_account.external_id).fetch('card')
    def get_forward(forward_id:)
      content=Content.find(forward_id.to_s.delete_prefix('fake-forward-'))
      Media::ForwardStructure.onebot_nodes(content) { |asset|{'file'=>"fake://#{asset.id}"} }
    end
    def get_message(message_external_id:)
      m=Message.find_by!(external_id:message_external_id)
      {'message_id'=>m.external_id,'group_id'=>m.group.external_id,'message'=>m.body}
    end
    def send_content(group:,entry:,kind:,idempotency_key:)
      raise RemoteError,'机器人当前不在目标群' unless group.group_bot_memberships.exists?(bot_account:@connection.bot_account,active:true)
      # Deterministic receipt implements idempotent fake transport without inventing a real OneBot guarantee.
      "fake-bot-#{Digest::SHA256.hexdigest(idempotency_key)[0,24]}"
    end
    def set_bot_card(group:,card:)
      membership=group.group_bot_memberships.find_by!(bot_account:@connection.bot_account)
      payload={'post_type'=>'notice','notice_type'=>'group_card','self_id'=>@connection.bot_account.external_id,'group_id'=>group.external_id,'user_id'=>@connection.bot_account.external_id,'card_new'=>card,'time'=>Time.current.to_i}
      Events::Ingestor.call(payload:payload,connection:@connection)
    end
  end
end
