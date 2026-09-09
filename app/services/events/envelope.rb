module Events
  Envelope = Data.define(:event_id, :event_type, :group_external_id, :sender_external_id, :message_external_id, :occurred_at, :reply_to_message_id, :content_type, :media_references, :metadata)
end
