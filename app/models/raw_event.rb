class RawEvent < ApplicationRecord
  belongs_to :bot_connection, class_name: "BotConnection"
end
