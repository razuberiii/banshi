# Optional forward WebSocket transport. Domain work always runs as jobs.
require 'websocket-client-simple'
raise 'NAPCAT_ENABLED=false' unless AppConfig.napcat.enabled
connection=BotConnection.find(Integer(ARGV.fetch(0)))
raise 'Choose a real adapter connection' unless connection.adapter=='real'
stopping=false
%w[INT TERM].each { |signal| Signal.trap(signal) { stopping=true } }
until stopping
  closed=false
  socket=WebSocket::Client::Simple.connect(AppConfig.napcat.ws_url,headers:{'Authorization'=>"Bearer #{connection.access_token}"})
  socket.on(:message) do |frame|
    Rails.application.executor.wrap do
      payload=JSON.parse(frame.data)
      next unless payload['post_type']
      next unless payload['self_id'].to_s==connection.bot_account.external_id
      Events::Ingestor.call(payload:payload,connection:connection)
    rescue StandardError=>error
      DomainLog.error(error,context:'onebot_ws',connection_id:connection.id)
    end
  end
  socket.on(:error) { |error| DomainLog.emit('onebot.ws_error',connection_id:connection.id,error_class:error.class.name) }
  socket.on(:close) { closed=true }
  sleep 0.25 until closed || stopping
  socket.close
  sleep AppConfig.napcat.reconnect_delay unless stopping
end
