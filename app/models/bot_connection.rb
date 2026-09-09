class BotConnection < ApplicationRecord
  belongs_to :bot_account, class_name: "BotAccount"
  def access_token = AppConfig.napcat.connection_tokens.fetch(credential_env_key,AppConfig.napcat.access_token)
end
