class OccurrenceRecorder
  def self.call(entry:, message:, source: 'NATURAL', delivery: nil, trial_run: nil, duplicate_matched: false, confidence: nil)
    raise ArgumentError, 'unsupported occurrence source' unless ShitOccurrence::SOURCES.include?(source)
    if source == 'NATURAL' && (message.source != 'NATURAL' || message.bot_account_id.present?)
      raise ArgumentError, 'bot delivery cannot be a natural occurrence'
    end
    occurrence = entry.with_lock do
      existing = ShitOccurrence.find_by(message_id: message.id)
      if existing
        raise ArgumentError, 'message already belongs to another entry' unless existing.shit_entry_id == entry.id
        next existing
      end
      created = ShitOccurrence.create!(shit_entry: entry, group: message.group, transporter: message.transporter,
        message: message, delivery: delivery, trial_run: trial_run, source: source,
        occurred_at: message.sent_at, duplicate_matched: duplicate_matched, match_confidence: confidence)
      TimelineEvent.create_or_find_by!(dedupe_key: "occurrence:#{created.id}") do |event|
        event.assign_attributes(shit_entry: entry, group: message.group, transporter: message.transporter,
          event_type: source == 'NATURAL' ? 'natural_occurrence' : source.downcase,
          label: source == 'NATURAL' ? '自然出现' : { 'BOT_TRIAL' => '机器人试吃', 'BOT_DISTRIBUTION' => '机器人传播', 'BOT_CLASSIC' => '经典考古' }.fetch(source),
          occurred_at: message.sent_at, details: { source: source, occurrence_id: created.id, duplicate_matched: duplicate_matched })
      end
      EntryStatsRefresh.call(entry)
      created
    end
    occurrence
  end
end
