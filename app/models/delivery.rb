class Delivery < ApplicationRecord
  belongs_to :shit_entry, class_name: "ShitEntry"
  belongs_to :group, class_name: "Group"
  belongs_to :bot_connection, class_name: "BotConnection"
  belongs_to :trial_run, class_name: "TrialRun", optional: true
  belongs_to :message, class_name: "Message", optional: true
end
