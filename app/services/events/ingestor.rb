module Events
  class Ingestor
    def self.call(payload:, connection:, enqueue: true)
      digest=Digest::SHA256.hexdigest(JSON.generate(payload))
      raw=RawEvent.create_or_find_by!(bot_connection:connection,digest:digest) do |r|
        r.payload=Normalizer.redact(payload); r.received_at=Time.current
      end
      Normalizer.call(payload,bot_external_id:connection.bot_account.external_id).map do |event|
        record=InternalEvent.create_or_find_by!(event_id:event.event_id) do |r|
          r.assign_attributes(event.to_h.except(:event_id)); r.raw_event=raw; r.bot_connection=connection
        end
        EventProcessJob.perform_later(record.id) if enqueue && record.status=='pending'
        record
      end
    end
  end
end
