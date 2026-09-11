class TrialEvaluator
  def self.call(run:, now: Time.current)
    entry = run.shit_entry
    result = nil
    entry.with_lock do
      run.lock!
      return run.trial_result if run.trial_result
      return run unless run.status == 'running' && run.ends_at && now >= run.ends_at
      sent = run.trial_deliveries.includes(delivery: :message).select { |row| row.delivery.status == 'sent' }
      unresolved = run.deliveries.where(status: %w[pending sending uncertain])
      if unresolved.exists?
        run.update!(explanation: run.explanation.merge('reason' => 'waiting_for_delivery_resolution', 'unresolved_deliveries' => unresolved.count))
        TrialFinishJob.set(wait: [AppConfig.distribution.cooldown, 60].max).perform_later(run.id)
        return run
      end
      if sent.empty? || (run.explanation['minimum_groups'] && sent.length < run.explanation['minimum_groups'])
        run.update!(status: 'pending', explanation: run.explanation.merge('reason' => 'waiting_for_groups', 'sent_groups' => sent.length))
        TrialDispatchJob.perform_later(entry.id)
        return run
      end
      config = AppConfig.trial
      groups = sent.map { |row| evaluate_group(row, entry, run, config) }
      total = groups.length
      responsive = groups.count { |group| group.fetch('responsive') }
      positive_groups = groups.count { |group| group.fetch('state') == 'positive' }
      good = groups.sum { |group| group.fetch('good_reactions') }
      funny = groups.sum { |group| group.fetch('funny_reactions') }
      bad = groups.sum { |group| group.fetch('bad_reactions') }
      reply_users = groups.flat_map { |group| group.fetch('reply_user_ids') }.uniq.length
      interaction_users = groups.flat_map { |group| group.fetch('interaction_user_ids') }.uniq.length
      reaction_total = good + funny + bad
      positive_rate = positive_groups.to_f / total
      responsive_rate = responsive.to_f / total
      response_positive_rate = responsive.positive? ? positive_groups.to_f / responsive : 0.0
      negative_rate = reaction_total.positive? ? bad.to_f / reaction_total : 0.0
      enough_response = responsive >= config.min_responsive_groups && responsive.positive?
      passed = enough_response && response_positive_rate >= config.positive_threshold && negative_rate <= config.negative_max
      verdict = responsive.zero? ? 'unknown' : passed ? 'passed' : 'failed'
      score = (good * config.good_weight + funny * config.funny_weight + reply_users - bad * config.bad_weight).to_f
      explanation = {
        'positive_groups' => positive_groups, 'unknown_groups' => groups.count { |group| group.fetch('state') == 'unknown' },
        'positive_rate_denominator' => 'all_sent_trial_groups', 'negative_rate_denominator' => 'recognized_good_funny_bad_reactions',
        'responsive_group_rate_denominator' => 'all_sent_trial_groups',
        'response_positive_rate' => response_positive_rate, 'response_positive_rate_denominator' => 'responsive_groups',
        'minimum_responsive_groups' => config.min_responsive_groups, 'positive_threshold' => config.positive_threshold,
        'negative_max' => config.negative_max, 'reply_positive_min' => config.reply_positive_min,
        'score_formula' => 'good * good_weight + funny * funny_weight + distinct_reply_users - bad * bad_weight',
        'weights' => { 'good' => config.good_weight, 'funny' => config.funny_weight, 'bad' => config.bad_weight },
        'reason' => responsive.zero? ? 'no_response_unknown' : passed ? 'response_aware_thresholds_passed' : 'response_aware_thresholds_failed',
        'counting_rule' => '每群每种反馈按独立人计；全场互动人数去重；作者及撤销、窗口外反馈不计；沉默不记负面',
        'groups' => groups.map { |group| group.except('reply_user_ids', 'interaction_user_ids') }
      }
      result = TrialResult.create!(trial_run: run, trial_group_count: total, responsive_group_count: responsive,
        good_reactions: good, funny_reactions: funny, bad_reactions: bad, unique_reply_users: reply_users,
        unique_interaction_users: interaction_users, positive_rate: positive_rate, negative_rate: negative_rate,
        responsive_group_rate: responsive_rate, distribution_score: score, verdict: verdict, explanation: explanation)
      run.update!(status: 'finished', finished_at: now, explanation: run.explanation.merge('reason' => explanation.fetch('reason')))
      entry.update!(level: AppConfig.trial.required_before_distribution ? (passed ? 'NORMAL' : 'ARCHIVED') : entry.level, distribution_score: score)
      TimelineEvent.create_or_find_by!(dedupe_key: "trial:#{run.id}:finished") do |event|
        event.assign_attributes(shit_entry: entry, event_type: 'trial_finished', label: passed ? '试吃通过' : responsive.zero? ? '试吃无响应，保留档案' : '试吃未通过，保留档案',
          occurred_at: now, details: { trial_run_id: run.id, verdict: verdict, positive_rate: positive_rate, negative_rate: negative_rate, responsive_group_rate: responsive_rate })
      end
    end
    if result
      LevelEvaluator.call(entry, now: now)
      ReputationRefreshJob.perform_later(entry.first_transporter_id) if entry.first_transporter_id
      run.trial_deliveries.each { |row| GroupStatsRefreshJob.perform_later(row.group_id) }
      DistributionJob.perform_later(entry.id) if result.verdict == 'passed' && SafetyEvaluator.call(entry: entry).allowed?
    end
    result || run
  end

  def self.evaluate_group(row, entry, run, config)
    delivery = row.delivery
    interactions = Interaction.where(group_id: row.group_id, target_external_id: delivery.external_message_id,
      active: true, occurred_at: delivery.sent_at..run.ends_at)
    interactions = interactions.where.not(transporter_id: entry.first_transporter_id) if entry.first_transporter_id
    interactions = interactions.to_a
    reactions = interactions.select { |interaction| interaction.kind == 'reaction' }
    good_ids = reactions.select { |interaction| interaction.reaction == config.reaction_good }.map(&:transporter_id).uniq
    funny_ids = reactions.select { |interaction| interaction.reaction == config.reaction_funny }.map(&:transporter_id).uniq
    bad_ids = reactions.select { |interaction| interaction.reaction == config.reaction_bad }.map(&:transporter_id).uniq
    reply_ids = interactions.select { |interaction| %w[reply quote].include?(interaction.kind) }.map(&:transporter_id).uniq
    user_ids = (good_ids + funny_ids + bad_ids + reply_ids).uniq
    positive_score = good_ids.length * config.good_weight + funny_ids.length * config.funny_weight
    negative_score = bad_ids.length * config.bad_weight
    positive = positive_score > negative_score || (reply_ids.length >= config.reply_positive_min && bad_ids.empty?)
    state = if user_ids.empty?
      'unknown'
    elsif positive
      'positive'
    elsif bad_ids.any?
      'negative'
    else
      'neutral'
    end
    stats = { 'group_id' => row.group_id, 'state' => state, 'responsive' => user_ids.any?, 'good_reactions' => good_ids.length,
      'funny_reactions' => funny_ids.length, 'bad_reactions' => bad_ids.length, 'unique_reply_users' => reply_ids.length,
      'unique_interaction_users' => user_ids.length, 'positive_score' => positive_score, 'negative_score' => negative_score }
    row.update!(feedback_state: state, stats: stats)
    stats.merge('reply_user_ids' => reply_ids, 'interaction_user_ids' => user_ids)
  end
  private_class_method :evaluate_group
end
