class TrialDispatcher
  def self.call(entry:, now: Time.current)
    return unless AppConfig.features.trial && AppConfig.trial.enabled && SafetyEvaluator.call(entry: entry).allowed?
    queued = []
    run = Distributor.with_reservation_lock do
      entry.lock!
      next unless SafetyEvaluator.call(entry: entry).allowed?
      active = entry.trial_runs.active.first
      next entry.trial_runs.order(:id).last if !active && entry.trial_runs.exists?
      next unless %w[ARCHIVED TRIAL NORMAL HOT CLASSIC].include?(entry.level)
      optional = !AppConfig.trial.required_before_distribution
      next if optional && TrialSelector.call(entry: entry, now: now).empty?
      active ||= entry.trial_runs.create!(status: 'pending', explanation: { 'requested_at' => now.iso8601, 'minimum_groups' => (optional ? 1 : AppConfig.trial.group_min) })
      active.lock!
      next active if active.status == 'running'
      entry.update!(level: 'TRIAL') unless optional || entry.level == 'TRIAL'
      sent_count = active.deliveries.where(status: 'sent').count
      still_pending = active.deliveries.where(status: %w[pending sending uncertain]).count
      groups = TrialSelector.call(entry: entry, now: now).first([AppConfig.trial.group_max - sent_count - still_pending, 0].max)
      needed = [(optional ? 1 : AppConfig.trial.group_min) - sent_count - still_pending, 0].max
      if groups.length < needed
        active.update!(explanation: active.explanation.merge('reason' => 'waiting_for_groups', 'eligible_groups' => groups.length,
          'sent_groups' => sent_count, 'reserved_groups' => still_pending, 'minimum_groups' => (optional ? 1 : AppConfig.trial.group_min),
          'last_checked_at' => now.iso8601, 'maximum_wait_exceeded' => now >= active.created_at + AppConfig.trial.max_wait))
        next active
      end

      groups.each do |group|
        delivery = Distributor.reserve!(entry: entry, group: group, kind: 'BOT_TRIAL', now: now, trial_run: active)
        queued << delivery if delivery
      end
      if queued.length < needed
        queued.each(&:destroy!)
        queued.clear
        active.update!(explanation: active.explanation.merge('reason' => 'waiting_for_quota', 'minimum_groups' => (optional ? 1 : AppConfig.trial.group_min), 'last_checked_at' => now.iso8601))
        next active
      end
      queued.each { |delivery| TrialDelivery.find_or_create_by!(trial_run: active, group: delivery.group) { |row| row.delivery = delivery } }
      active.update!(status: 'running', started_at: active.started_at || now, ends_at: now + AppConfig.trial.duration,
        explanation: active.explanation.merge('reason' => 'groups_reserved', 'minimum_groups' => (optional ? 1 : AppConfig.trial.group_min),
          'selected_group_ids' => active.trial_deliveries.pluck(:group_id), 'selection_rule' => 'OPT_IN 优先，FALLBACK 补位，按 last_trial_at 轮转，排除原群和自然出现群'))
      TimelineEvent.create_or_find_by!(dedupe_key: "trial:#{active.id}:started") do |event|
        event.assign_attributes(shit_entry: entry, event_type: 'trial_started', label: '进入试吃观察', occurred_at: now,
          details: { trial_run_id: active.id, group_count: queued.length + sent_count + still_pending })
      end
      active
    end
    return unless run
    queued.each { |delivery| DeliveryJob.perform_later(delivery.id) }
    if run.status == 'pending'
      TrialDispatchJob.set(wait: [AppConfig.distribution.cooldown, 60].max).perform_later(entry.id)
    elsif run.status == 'running'
      TrialFinishJob.set(wait_until: run.ends_at).perform_later(run.id)
    end
    run
  end
end
