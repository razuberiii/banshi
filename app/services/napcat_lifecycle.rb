class NapcatLifecycle
  # Probe before creating an account: a logged-out instance has no fake QQ ID.
  def self.sync!(name:, endpoint:, credential_key: name, adapter: nil)
    probe = BotConnection.new(endpoint: endpoint, credential_env_key: credential_key)
    adapter ||= Adapters::RealNapCatAdapter.new(probe)
    identity = adapter.get_login_info
    external_id = identity['user_id'].to_s
    raise Adapters::OneBotAdapter::RemoteError, 'Waiting for QQ login' unless external_id.match?(/\A[1-9]\d*\z/)
    groups = adapter.get_group_list
    raise Adapters::OneBotAdapter::RemoteError, 'Invalid group list' unless groups.is_a?(Array)
    now = Time.current
    connection = BotConnection.transaction do
      BotConnection.connection.execute('SELECT pg_advisory_xact_lock(713403)')
      bot = BotAccount.find_or_initialize_by(external_id: external_id)
      bot.update!(name: identity['nickname'].presence || 'Banshi', active: true)
      connection = BotConnection.find_or_initialize_by(adapter: 'real', name: name)
      changed = connection.new_record? || connection.status != 'online' || connection.bot_account_id != bot.id
      connection.update!(bot_account: bot, endpoint: endpoint, credential_env_key: credential_key,
        status: 'online', last_seen_at: now)
      ids = groups.map { |row| row.fetch('group_id').to_s }
      bot.group_bot_memberships.where.not(group_id: Group.where(external_id: ids).select(:id)).update_all(active: false)
      groups.each do |row|
        group = Group.find_or_initialize_by(external_id: row.fetch('group_id').to_s)
        if group.new_record?
          suffix = SecureRandom.hex(6)
          group.assign_attributes(slug: "g-#{suffix}", public_name: "Group #{suffix}",
            anonymous_name: "Group #{suffix}", joined_at: now)
          group.save!
        end
        membership = group.group_bot_memberships.find_or_initialize_by(bot_account: bot)
        membership.assign_attributes(active: true, joined_at: membership.joined_at || now)
        begin
          info = adapter.get_group_member_info(group_external_id: group.external_id, user_external_id: external_id)
          membership.assign_attributes(role: info.fetch('role', 'member'), card: info.fetch('card', ''))
        rescue Adapters::OneBotAdapter::RemoteError
          # Membership comes from get_group_list; a role lookup may be retried.
        end
        membership.save!
        DomainLog.emit('group.synced', group_id: group.id, bot_account_id: bot.id)
      end
      DomainLog.emit('bot.online', bot_account_id: bot.id, connection_id: connection.id) if changed
      connection
    end
    connection
  rescue Adapters::OneBotAdapter::RemoteError => error
    connections = BotConnection.where(adapter: 'real', name: name)
    connections.where(status: 'online').each { |row| DomainLog.emit('bot.offline', connection_id: row.id) }
    connections.update_all(status: 'offline')
    DomainLog.emit('napcat.waiting_login', connection_name: name, error_class: error.class.name)
    nil
  end
end
