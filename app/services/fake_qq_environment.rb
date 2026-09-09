class FakeQQEnvironment
  def initialize(group:,transporter:,at:Time.current,key:SecureRandom.uuid)
    @connection=group.available_connection
    raise ArgumentError,'这个群没有可用的 Fake 机器人' unless @connection&.adapter=='fake'
    @generator=FakeEventGenerator.new(connection:@connection,group:group,transporter:transporter,at:at,key:key)
  end
  def send_image(asset:) = submit(@generator.image(asset))
  def send_forward(content:) = submit(@generator.forward(content))
  def reply(target:) = submit(@generator.reply(target))
  def react(target:,emoji:,active:true) = submit(@generator.reaction(target,emoji:emoji,active:active))
  def claim(token:) = submit(@generator.claim(token))
  private
  def submit(payload)
    records=Events::Ingestor.call(payload:payload,connection:@connection,enqueue:false)
    records.each { |event|Events::Processor.call(event) }
    records.first
  end
end
