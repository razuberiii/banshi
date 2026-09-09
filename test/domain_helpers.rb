require 'test_helper'
require 'minitest/mock'

module DomainHelpers
  def domain_group(**attributes)
    token = SecureRandom.hex(5)
    Group.create!({ external_id: "g-#{token}", slug: "group-#{token}", public_name: "测试文化馆 #{token}", anonymous_name: "匿名文化馆 #{token}", joined_at: 1.year.ago, visibility: 'public', anonymous: false, hide_members: false }.merge(attributes))
  end

  def domain_transporter(**attributes)
    token = SecureRandom.hex(5)
    Transporter.create!({ external_id: "person-#{token}", display_name: "搬运者 #{token}", public_profile: true }.merge(attributes))
  end

  def domain_content(kind: 'image', fingerprint: SecureRandom.hex(32))
    Content.create!(kind: kind, fingerprint: fingerprint)
  end

  def domain_message(group: domain_group, content: domain_content, transporter: domain_transporter, at: Time.current, **attributes)
    Message.create!({ group: group, content: content, transporter: transporter, external_id: "m-#{SecureRandom.hex(6)}", kind: content.kind, sent_at: at, source: 'NATURAL' }.merge(attributes))
  end

  def domain_entry(group: domain_group, content: domain_content, transporter: domain_transporter, at: Time.current, **attributes)
    ShitEntry.create!({ first_group: group, content: content, first_transporter: transporter, first_seen_at: at, last_natural_at: at }.merge(attributes))
  end

  def domain_interaction(message:, transporter: domain_transporter, kind: 'reply', reaction: '', at: Time.current, active: true)
    Interaction.create!(group: message.group, message: message, transporter: transporter, target_external_id: message.external_id, kind: kind, reaction: reaction, active: active, occurred_at: at, identity_key: SecureRandom.hex(20))
  end

  def domain_bot(*groups)
    bot = BotAccount.create!(external_id: "bot-#{SecureRandom.hex(5)}", name: '测试搬运机器人')
    connection = BotConnection.create!(bot_account: bot, name: '测试 Fake QQ', adapter: 'fake', status: 'online')
    groups.each { |group| GroupBotMembership.create!(group: group, bot_account: bot, joined_at: 1.day.ago, active: true) }
    connection
  end

  def domain_user(**attributes)
    token = SecureRandom.hex(5)
    User.create!({ email: "#{token}@example.test", display_name: "读者 #{token}", password: 'Domain-tests-2026!' }.merge(attributes))
  end

  def domain_sent_trial(entry:, groups:, at: Time.current)
    run = TrialRun.create!(shit_entry: entry, status: 'running', started_at: at, ends_at: at + AppConfig.trial.duration)
    connection = domain_bot(*groups)
    groups.each do |group|
      message = domain_message(group: group, content: entry.content, transporter: nil, bot_account: connection.bot_account, source: 'BOT_TRIAL', at: at)
      delivery = Delivery.create!(shit_entry: entry, group: group, bot_connection: connection, trial_run: run, message: message, kind: 'BOT_TRIAL', status: 'sent', idempotency_key: SecureRandom.hex(20), external_message_id: message.external_id, sent_at: at)
      TrialDelivery.create!(trial_run: run, group: group, delivery: delivery)
      OccurrenceRecorder.call(entry: entry, message: message, source: 'BOT_TRIAL', delivery: delivery, trial_run: run)
    end
    run
  end
end
