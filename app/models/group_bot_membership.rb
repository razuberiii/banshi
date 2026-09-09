class GroupBotMembership < ApplicationRecord
  belongs_to :group, class_name: "Group"
  belongs_to :bot_account, class_name: "BotAccount"
end
