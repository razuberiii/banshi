class BotConnection < ApplicationRecord
  belongs_to :bot_account, class_name: "BotAccount"
end
