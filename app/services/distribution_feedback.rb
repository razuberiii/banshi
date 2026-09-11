class DistributionFeedback
  def self.call(entry:)
    deliveries = entry.deliveries.where(status: 'sent')
    latest = deliveries.where.not(kind: 'BOT_TRIAL').maximum(:sent_at)
    scope = Interaction.where(message_id: deliveries.select(:message_id), active: true)
    scope = scope.where.not(transporter_id: entry.first_transporter_id) if entry.first_transporter_id
    positive = scope.where(kind: 'reaction', reaction: [AppConfig.trial.reaction_good, AppConfig.trial.reaction_funny]).distinct.count(:transporter_id)
    negative = scope.where(kind: 'reaction', reaction: AppConfig.trial.reaction_bad).distinct.count(:transporter_id)
    replies = scope.where(kind: %w[reply quote]).distinct.count(:transporter_id)
    natural = latest ? entry.natural_occurrences.where('occurred_at > ?', deliveries.minimum(:sent_at)).count : 0
    signals = positive + replies + natural
    state = negative > positive + natural ? 'negative' : signals.positive? ? 'responsive' : 'unknown'
    { state: state, positive: positive, negative: negative, replies: replies, natural: natural,
      signals: signals, last_sent_at: latest, score: positive * 2 + replies + natural * 3 - negative * 2 }
  end
end
