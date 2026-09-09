require 'digest'

module Events
  module Ordering
    # Lock a domain identity, including rows which do not exist yet. Locking
    # each InternalEvent alone cannot serialize two updates to one reaction.
    def self.with_lock(key)
      number=Digest::SHA256.digest(key).unpack1('l>')
      InternalEvent.transaction do
        InternalEvent.connection.execute("SELECT pg_advisory_xact_lock(713410, #{number})")
        yield
      end
    end

    # OneBot timestamps have second resolution. Use durable ingestion order
    # only to break equal-time ties; a replay of an older event cannot win.
    def self.newer?(event, timestamp, event_id)
      timestamp.nil? || ([event.occurred_at,event.id] <=> [timestamp,event_id.to_i]) == 1
    end
  end
end
