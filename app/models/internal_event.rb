class InternalEvent < ApplicationRecord
  belongs_to :raw_event, class_name: "RawEvent", optional: true
  belongs_to :bot_connection, class_name: "BotConnection", optional: true
end
