# Persistent login discovery + forward WebSocket events. No QQ ID is configured.
require 'websocket-client-simple'
raise 'NAPCAT_ENABLED=false' unless AppConfig.napcat.enabled
stopping = false
%w[INT TERM].each { |signal| Signal.trap(signal) { stopping = true } }
configs = AppConfig.napcat.connections.presence || {
  'primary' => { 'http_url' => AppConfig.napcat.http_url, 'ws_url' => AppConfig.napcat.ws_url }
}
threads = configs.map do |name, config|
  Thread.new do
    until stopping
      socket = nil
      connection = nil
      begin
        connection = Rails.application.executor.wrap do
          NapcatLifecycle.sync!(name: name, endpoint: config.fetch('http_url'), credential_key: name)
        end
        if connection
          closed = false
          socket = WebSocket::Client::Simple.connect(config.fetch('ws_url'), headers: { 'Authorization' => "Bearer #{connection.access_token}" })
          socket.on(:open) { DomainLog.emit('napcat.connected', connection_id: connection.id) }
          socket.on(:message) do |frame|
            Rails.application.executor.wrap do
              payload = JSON.parse(frame.data)
              next unless payload['post_type'] && payload['self_id'].to_s == connection.bot_account.external_id
              Events::Ingestor.call(payload: payload, connection: connection)
            rescue StandardError => error
              # Protocol errors must never include frame contents or credentials.
              DomainLog.emit('napcat.event_error', connection_id: connection.id, error_class: error.class.name)
            end
          end
          socket.on(:error) { closed = true }
          socket.on(:close) { closed = true }
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + AppConfig.napcat.sync_interval
          until closed || stopping
            sleep 0.25
            next if Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
            current = Rails.application.executor.wrap do
              NapcatLifecycle.sync!(name: name, endpoint: config.fetch('http_url'), credential_key: name)
            end
            break unless current && current.bot_account_id == connection.bot_account_id
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + AppConfig.napcat.sync_interval
          end
        end
      rescue StandardError => error
        DomainLog.emit('napcat.disconnected', connection_name: name, error_class: error.class.name)
      ensure
        socket&.close
        if connection
          Rails.application.executor.wrap { connection.update!(status: 'offline') }
          DomainLog.emit('napcat.disconnected', connection_id: connection.id)
        end
      end
      (AppConfig.napcat.reconnect_delay * 4).times { break if stopping; sleep 0.25 }
    end
  end
end
threads.each(&:join)
