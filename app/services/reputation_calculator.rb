class ReputationCalculator
  def self.call(transporter)
    return unless transporter
    transporter.with_lock do
      config = AppConfig.reputation
      settled = transporter.candidates.where(status: %w[accepted duplicate expired rejected unsafe])
      samples = settled.count
      accepted = settled.where(status: %w[accepted duplicate]).count
      natural = transporter.shit_occurrences.natural.count
      classics = transporter.discoveries.unmerged.where(level: 'CLASSIC').count
      natural_bonus = [natural - accepted, 0].max * config.natural_weight
      classic_bonus = classics * config.classic_weight
      successes = accepted + natural_bonus + classic_bonus
      failures = samples - accepted
      numerator = config.prior_successes + successes
      denominator = config.prior_successes + config.prior_failures + successes + failures
      score = numerator.to_f / denominator
      enabled = AppConfig.features.reputation && config.enabled
      adjustment = enabled && samples >= config.min_samples ? (score - 0.5) * 2 * config.max_adjustment : 0.0
      transporter.update!(candidate_count: transporter.candidates.count, accepted_count: accepted, natural_count: natural,
        classic_count: classics, reputation_score: enabled ? score : 0.5,
        reputation_details: { settled_samples: samples, accepted_samples: accepted, failures: failures,
          natural_bonus: natural_bonus, classic_bonus: classic_bonus, prior_successes: config.prior_successes,
          prior_failures: config.prior_failures, posterior_numerator: numerator,
          posterior_denominator: denominator, minimum_samples: config.min_samples, adjustment: adjustment,
          enabled: enabled, formula: '(prior_successes + accepted + natural_bonus + classic_bonus) / (prior_total + accepted + bonuses + failures)' })
    end
    transporter
  end
end
