class GroupStatsRefresh
  def self.call(group)
    group.with_lock do
      natural = group.shit_occurrences.natural
      trials = group.trial_deliveries.joins(:delivery).where(deliveries: { status: 'sent' })
      reactions = Interaction.where(group: group, kind: 'reaction', active: true)
        .joins(:message).where('messages.transporter_id IS NULL OR messages.transporter_id <> interactions.transporter_id')
      good = reactions.where(reaction: AppConfig.trial.reaction_good).distinct.count(:transporter_id)
      funny = reactions.where(reaction: AppConfig.trial.reaction_funny).distinct.count(:transporter_id)
      bad = reactions.where(reaction: AppConfig.trial.reaction_bad).distinct.count(:transporter_id)
      bot_interactions = Interaction.where(group: group, active: true, message_id: group.deliveries.where(status: 'sent').select(:message_id))
      response = {
        positive: bot_interactions.where(kind: 'reaction', reaction: [AppConfig.trial.reaction_good, AppConfig.trial.reaction_funny]).distinct.count(:transporter_id),
        negative: bot_interactions.where(kind: 'reaction', reaction: AppConfig.trial.reaction_bad).distinct.count(:transporter_id),
        replies: bot_interactions.where(kind: %w[reply quote]).distinct.count(:transporter_id)
      }
      group.update!(stats: {
        distribution_response: response,
        discoveries: group.discovered_entries.unmerged.count,
        classic_discoveries: group.discovered_entries.unmerged.where(level: 'CLASSIC').count,
        natural_occurrences: natural.count, natural_entries: natural.distinct.count(:shit_entry_id),
        bot_occurrences: group.shit_occurrences.bot.count,
        unique_transporters: natural.where.not(transporter_id: nil).distinct.count(:transporter_id),
        trial_deliveries: trials.count, responsive_trials: trials.where.not(feedback_state: 'unknown').count,
        positive_trials: trials.where(feedback_state: 'positive').count, negative_trials: trials.where(feedback_state: 'negative').count,
        unknown_trials: trials.where(feedback_state: 'unknown').count,
        taste_profile: { good_users: good, funny_users: funny, bad_users: bad,
          basis: '可计数的有效互动，未分析文字或推断内容语义' }, refreshed_at: Time.current.iso8601
      })
    end
    group
  end
end
