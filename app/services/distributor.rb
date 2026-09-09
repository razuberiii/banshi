class Distributor
  DELIVERY_KINDS = %w[BOT_TRIAL BOT_DISTRIBUTION BOT_CLASSIC].freeze

  def self.call(entry:, now: Time.current, kind: 'BOT_DISTRIBUTION')
    kind = 'BOT_CLASSIC' if kind == 'BOT_DISTRIBUTION' && entry.level == 'CLASSIC'
    raise ArgumentError, 'unsupported distribution kind' unless DELIVERY_KINDS.include?(kind)
    return [] unless AppConfig.distribution.enabled && AppConfig.distribution.batch_size.positive? && %w[NORMAL HOT CLASSIC].include?(entry.level)
    deliveries = with_reservation_lock do
      entry.lock!
      next [] unless SafetyEvaluator.call(entry: entry).allowed?
      selected = []
      Group.order(Arel.sql('last_delivery_at ASC NULLS FIRST'), :id).each do |group|
        delivery = reserve!(entry: entry, group: group, kind: kind, now: now)
        selected << delivery if delivery
        break if selected.length >= AppConfig.distribution.batch_size
      end
      selected
    end
    deliveries.each { |delivery| DeliveryJob.perform_later(delivery.id) }
    deliveries
  end

  # All dispatchers share the same transaction-level lock before checking and
  # reserving quota. Row locks alone cannot protect a platform-wide minute cap.
  def self.with_reservation_lock
    Delivery.transaction do
      Delivery.connection.execute('SELECT pg_advisory_xact_lock(713402)')
      yield
    end
  end

  def self.reserve!(entry:, group:, kind:, now:, trial_run: nil)
    group.with_lock do
      last_sent_id = entry.deliveries.where(group: group, kind: kind, status: 'sent').order(sent_at: :desc, id: :desc).pick(:id) || 0
      key = trial_run ? "trial:#{trial_run.id}:group:#{group.id}" : "entry:#{entry.id}:group:#{group.id}:#{kind}:after:#{last_sent_id}"
      existing = Delivery.find_by(idempotency_key: key)
      return existing if existing && %w[pending sending sent uncertain].include?(existing.status)
      match = GroupMatcher.call(entry: entry, group: group, kind: kind, now: now, excluding_delivery: existing)
      return unless match.allowed?
      delivery = existing || Delivery.new(idempotency_key: key)
      delivery.assign_attributes(shit_entry: entry, group: group, bot_connection: match.connection, trial_run: trial_run,
        kind: kind, status: 'pending', error_message: nil,
        decision: { 'reserved_at' => now.iso8601(6), 'reasons' => [], 'daily_limit' => group.effective_daily_limit,
          'cooldown_seconds' => group.cooldown, 'global_per_minute' => AppConfig.distribution.global_per_minute })
      delivery.save!
      delivery
    end
  end

  def self.deliver!(delivery:, now: Time.current)
    ready = with_reservation_lock do
      entry = delivery.shit_entry
      entry.lock!
      delivery.group.lock!
      delivery.lock!
      next false if %w[sent uncertain cancelled].include?(delivery.status)
      if delivery.status == 'sending'
        delivery.update!(status: 'uncertain', error_message: 'previous worker stopped during send; reconcile externally before any retry')
        next false
      end
      match = GroupMatcher.call(entry: entry, group: delivery.group, kind: delivery.kind, now: now, excluding_delivery: delivery)
      unless match.allowed?
        transient = (match.reasons - %w[daily_quota group_cooldown global_minute_quota no_online_bot_membership]).empty?
        delivery.update!(status: transient ? 'pending' : 'cancelled', error_message: match.reasons.join(', '),
          decision: delivery.decision.merge('send_recheck_at' => now.iso8601, 'reasons' => match.reasons))
        DeliveryJob.set(wait: retry_delay(delivery.group)).perform_later(delivery.id) if transient
        next false
      end
      delivery.update!(status: 'sending', bot_connection: match.connection, error_message: nil,
        decision: delivery.decision.merge('reserved_at' => now.iso8601(6), 'send_started_at' => now.iso8601(6), 'reasons' => []))
      true
    end
    return delivery unless ready

    # The sending state is committed before the external side effect. A worker
    # crash cannot turn a possibly sent message into a blind retry.
    begin
      entry = delivery.shit_entry.reload
      safety = SafetyEvaluator.call(entry: entry, group: delivery.group.reload)
      unless safety.allowed?
        delivery.update!(status: 'cancelled', error_message: safety.reasons.join(', '))
        return delivery
      end
      external_id = Adapters::Registry.for(delivery.bot_connection).send_content(
        group: delivery.group, entry: entry, kind: delivery.kind, idempotency_key: delivery.idempotency_key)
      raise Adapters::OneBotAdapter::AmbiguousDelivery, 'adapter returned no external message id' if external_id.to_s.empty?
      complete_send!(delivery, external_id.to_s, now)
    rescue Adapters::OneBotAdapter::AmbiguousDelivery => error
      delivery.reload.update!(status: 'uncertain', error_message: error.message.to_s.first(1000))
      DomainLog.error(error, context: 'delivery_uncertain', delivery_id: delivery.id)
    rescue StandardError => error
      # If the adapter returned an ID, the send succeeded even if persistence
      # failed. That failure must also be reconciled, not resent.
      delivery.reload.update!(status: external_id.present? ? 'uncertain' : 'failed',
        external_message_id: external_id.presence || delivery.external_message_id, error_message: error.message.to_s.first(1000))
      DomainLog.error(error, context: 'delivery', delivery_id: delivery.id, external_message_id: external_id)
      raise
    end
    delivery
  end

  def self.complete_send!(delivery, external_id, now)
    Delivery.transaction do
      entry = delivery.shit_entry
      entry.lock!
      delivery.group.lock!
      delivery.lock!
      message = Message.find_or_initialize_by(group: delivery.group, external_id: external_id)
      if message.persisted? && (message.bot_account_id != delivery.bot_connection.bot_account_id ||
          message.shit_occurrence.present? || (message.content_id && message.content_id != entry.content_id))
        raise ArgumentError, 'send receipt conflicts with an existing message; reconcile before attaching history'
      end
      message.assign_attributes(content: entry.content, bot_account: delivery.bot_connection.bot_account,
        transporter: nil, source: delivery.kind, kind: entry.content.kind, sent_at: now)
      message.save!
      Interaction.where(group:delivery.group,target_external_id:external_id,message_id:nil).update_all(message_id:message.id)
      delivery.update!(status: 'sent', external_message_id: external_id, message: message, sent_at: now, error_message: nil)
      attributes = { last_delivery_at: now }
      attributes[:last_trial_at] = now if delivery.kind == 'BOT_TRIAL'
      delivery.group.update!(attributes)
      entry.update!(first_distributed_at: now) unless entry.first_distributed_at
      OccurrenceRecorder.call(entry: entry, message: message, source: delivery.kind, delivery: delivery, trial_run: delivery.trial_run)
      if delivery.trial_run
        run = delivery.trial_run
        run.with_lock do
          ends_at = [run.ends_at, now + AppConfig.trial.duration].compact.max
          run.update!(status: 'running', started_at: run.started_at || now, ends_at: ends_at)
          TrialFinishJob.set(wait_until: ends_at).perform_later(run.id)
        end
      end
    end
    GroupStatsRefreshJob.perform_later(delivery.group_id)
  end
  private_class_method :complete_send!

  def self.retry_delay(group)
    [group.cooldown, 60].max
  end
  private_class_method :retry_delay
end
