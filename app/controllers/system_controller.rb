class SystemController < ApplicationController
  before_action :require_curator
  def status
    @database = ActiveRecord::Base.connection.select_value('SELECT 1') == 1
    @worker = GoodJob::Process.where('updated_at > ?', 2.minutes.ago).exists?
    @connections = BotConnection.where(adapter: 'real').includes(:bot_account).order(:name)
    @napcat = if !AppConfig.napcat.enabled
      'DISABLED'
    elsif @connections.where(status: 'online').where('last_seen_at > ?', 2.minutes.ago).exists?
      'ONLINE'
    elsif @connections.empty?
      'WAITING LOGIN'
    else
      'OFFLINE / WAITING LOGIN'
    end
    @groups = GroupBotMembership.joins(bot_account: :bot_connections)
      .where(active: true, bot_connections: {adapter: 'real', status: 'online'}).distinct.count(:group_id)
    @candidates = Candidate.pending.count
    @deliveries = Delivery.where(status: %w[pending sending]).count
    @last_event = RawEvent.joins(:bot_connection).where(bot_connections: {adapter: 'real'}).maximum(:received_at)
  end
end
