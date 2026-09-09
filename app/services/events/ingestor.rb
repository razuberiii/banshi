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
        # NapCat exposes bounded 32-bit short IDs. A collision must not be
        # mistaken for a replay or overwrite the existing sender/history.
        if event.event_id.start_with?('message:') &&
            (record.sender_external_id!=event.sender_external_id || record.occurred_at.to_i!=event.occurred_at.to_i || record.content_type!=event.content_type || record.metadata['text']!=event.metadata['text'])
          record=InternalEvent.create_or_find_by!(event_id:"#{event.event_id}:conflict:#{raw.digest}") do |r|
            r.assign_attributes(event.to_h.except(:event_id));r.raw_event=raw;r.bot_connection=connection
            r.status='ignored';r.error_message='Conflicting OneBot short message ID; retained for reconciliation'
          end
          AuditLog.find_or_create_by!(category:'onebot',action:'message_id_conflict',details:{event_id:record.id})
        end
        EventProcessJob.perform_later(record.id) if enqueue && record.status=='pending'
        record
      end
    end
  end
end
