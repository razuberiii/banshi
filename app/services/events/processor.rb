module Events
  class Processor
    def self.call(event)
      failure=nil
      event.with_lock do
        return event if %w[processed ignored].include?(event.status)
        return event if event.attempts>=AppConfig.jobs.attempts
        event.increment!(:attempts)
        begin
          # A savepoint rolls back partial business writes without rolling
          # back the attempt counter in the enclosing event transaction.
          InternalEvent.transaction(requires_new:true) do
            new(event).call
            event.update!(status:'processed',error_message:nil)
          end
        rescue StandardError=>error
          event.reload.update!(status:'failed',error_message:error.message.to_s.first(500))
          failure=error
        end
      end
      if failure
        DomainLog.error(failure,context:'event',event_id:event.id)
        raise failure
      end
      DomainLog.emit('event.processed',event_id:event.id,type:event.event_type)
      event
    end
    def initialize(event)
      @event=event;@connection=event.bot_connection
      @adapter=Adapters::Registry.for(@connection) if @connection
    end
    def call
      return if @event.event_type=='UnsupportedEvent'
      @group=Group.find_or_create_by!(external_id:@event.group_external_id) do |g|
        suffix=SecureRandom.hex(4)
        g.assign_attributes(slug:"g-#{suffix}",public_name:"未命名群馆",anonymous_name:"匿名群馆 #{suffix}",joined_at:@event.occurred_at)
      end
      case @event.event_type
      when 'ImageMessageReceived','ForwardMessageReceived','GroupMessageReceived'
        bootstrap_bot_membership
        message
      when 'ReactionReceived' then reaction
      when 'BotGroupCardChanged' then card_changed
      when 'GroupMemberChanged' then member_changed
      when 'GroupMetadataChanged'
        # Names are not automatically published; retain private adapter metadata only.
        AuditLog.create!(group:@group,category:'group',action:'metadata_changed',details:{event_id:@event.id})
      end
    end
    private
    def sender
      @sender ||= Transporter.find_or_create_by!(external_id:@event.sender_external_id) do |t|
        t.display_name="匿名搬运者 #{SecureRandom.hex(3)}"
      end
    end
    def bootstrap_bot_membership
      return unless @connection
      @group.with_lock do
        # An old message must never reactivate a membership already marked
        # inactive. Only explicit, ordered membership notices may do that.
        return if @group.group_bot_memberships.exists?(bot_account:@connection.bot_account)
        card='未确认'
        confirmed=false
        begin
          card=@adapter.get_bot_card(group_external_id:@group.external_id).to_s
          confirmed=true
        rescue Adapters::OneBotAdapter::RemoteError,ActiveRecord::RecordNotFound,KeyError
          # Unknown cards disable collection/distribution until a later card
          # event or an explicit manager choice confirms a mode.
        end
        @group.group_bot_memberships.create!(bot_account:@connection.bot_account,joined_at:@event.occurred_at,active:true,card:card,
          card_event_at:confirmed ? @event.occurred_at : nil,card_event_id:confirmed ? @event.id : nil)
        if @group.mode_event_at.nil?
          @group.update!(mode:card,mode_event_at:confirmed ? @event.occurred_at : nil,mode_event_id:confirmed ? @event.id : nil)
        end
        AuditLog.create!(group:@group,category:'bot',action:'membership_bootstrapped',details:{bot_account_id:@connection.bot_account_id,card_confirmed:confirmed})
      end
    end
    def message
      return if @group.messages.exists?(external_id:@event.message_external_id)
      bot=BotAccount.find_by(external_id:@event.sender_external_id)
      content=bot ? nil : Media::ContentIngestor.call(event:@event,adapter:@adapter)
      message=@group.messages.create!(external_id:@event.message_external_id,transporter:bot ? nil : sender,bot_account:bot,internal_event:@event,content:content,source:bot ? 'BOT_DISTRIBUTION' : 'NATURAL',kind:@event.content_type,body:@event.metadata['text'],sent_at:@event.occurred_at,reply_to_external_id:@event.reply_to_message_id)
      Interaction.where(group:@group,target_external_id:message.external_id,message_id:nil).update_all(message_id:message.id)
      unless bot
        GroupMember.find_or_create_by!(group:@group,transporter:sender)
        verify_claim
        if @event.reply_to_message_id
          target=@group.messages.find_by(external_id:@event.reply_to_message_id)
          Interaction.create_or_find_by!(identity_key:"reply:#{@group.id}:#{message.external_id}") do |i|
            i.assign_attributes(group:@group,transporter:sender,message:target,internal_event:@event,target_external_id:@event.reply_to_message_id,kind:'reply',occurred_at:@event.occurred_at)
          end
          EntryStatsRefresh.call(target.shit_occurrence.shit_entry) if target&.shit_occurrence
        end
        Collector.collect(message:message) if content
      end
    end
    def reaction
      return if BotAccount.exists?(external_id:@event.sender_external_id)
      emoji=AppConfig.napcat.reaction_map[@event.metadata['emoji_id'].to_s]
      return unless emoji
      target=@group.messages.find_by(external_id:@event.message_external_id)
      key="reaction:#{@group.id}:#{@event.message_external_id}:#{sender.id}:#{emoji}"
      Ordering.with_lock(key) do
        i=Interaction.find_or_initialize_by(identity_key:key)
        return if i.persisted? && !Ordering.newer?(@event,i.occurred_at,i.internal_event_id)
        i.assign_attributes(group:@group,transporter:sender,message:target,internal_event:@event,target_external_id:@event.message_external_id,kind:'reaction',reaction:emoji,active:@event.metadata.fetch('active'),occurred_at:@event.occurred_at)
        i.save!
      end
      EntryStatsRefresh.call(target.shit_occurrence.shit_entry) if target&.shit_occurrence
    end
    def verify_claim
      digest=@event.metadata['claim_digest']
      return unless digest
      ids=Array(@event.metadata['mentioned_external_ids'])
      mentioned=BotConnection.joins(bot_account: :group_bot_memberships)
        .where(bot_accounts:{external_id:ids,active:true},group_bot_memberships:{group_id:@group.id,active:true},status:'online').order(:id).first
      return unless mentioned
      ClaimVerifier.call(digest:digest,group:@group,sender_external_id:sender.external_id,adapter:Adapters::Registry.for(mentioned),mentions_bot:true)
    end
    def card_changed
      @group.with_lock do
        membership=@group.group_bot_memberships.find_or_initialize_by(bot_account:@connection.bot_account)
        membership.joined_at ||= @event.occurred_at
        return unless Ordering.newer?(@event,membership.card_event_at,membership.card_event_id)
        membership.update!(card:@event.metadata.fetch('card'),card_event_at:@event.occurred_at,card_event_id:@event.id)
        if Ordering.newer?(@event,@group.mode_event_at,@group.mode_event_id)
          @group.update!(mode:@event.metadata.fetch('card'),mode_event_at:@event.occurred_at,mode_event_id:@event.id)
        end
        AuditLog.create!(group:@group,category:'bot',action:'card_changed',details:{bot_account_id:@connection.bot_account_id})
      end
    end
    def member_changed
      @group.with_lock do
        if @event.metadata['is_bot']
          return if @event.metadata['change']=='group_admin'
          member=@group.group_bot_memberships.find_or_initialize_by(bot_account:@connection.bot_account)
          member.joined_at ||= @event.occurred_at
        else
          member=GroupMember.find_or_initialize_by(group:@group,transporter:sender)
        end
        if @event.metadata['change']=='group_admin'
          return unless Ordering.newer?(@event,member.role_event_at,member.role_event_id)
          member.assign_attributes(role:@event.metadata['sub_type']=='set' ? 'admin' : 'member',role_event_at:@event.occurred_at,role_event_id:@event.id)
        else
          return unless Ordering.newer?(@event,member.membership_event_at,member.membership_event_id)
          member.assign_attributes(active:@event.metadata['change']!='group_decrease',membership_event_at:@event.occurred_at,membership_event_id:@event.id)
        end
        member.save!
      end
    end
  end
end
