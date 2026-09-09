class FakeEventGenerator
  def initialize(connection:,group:,transporter:,at:Time.current,key:SecureRandom.uuid)
    @base={'self_id'=>connection.bot_account.external_id,'group_id'=>group.external_id,'user_id'=>transporter.external_id,'time'=>at.to_i,'message_id'=>"fake-#{key}"}
  end
  def message(segments)
    @base.merge('post_type'=>'message','message_type'=>'group','sub_type'=>'normal','message'=>segments)
  end
  def image(asset) = message([{'type'=>'image','data'=>{'file'=>"fake://#{asset.id}"}}])
  def forward(content) = message([{'type'=>'forward','data'=>{'id'=>"fake-forward-#{content.id}"}}])
  def reply(target,text:'这段有点节目效果') = message([{'type'=>'reply','data'=>{'id'=>target.external_id}},{'type'=>'text','data'=>{'text'=>text}}])
  def reaction(target,emoji:,active:true)
    emoji_id=AppConfig.napcat.reaction_map.key(emoji) || emoji
    @base.merge('post_type'=>'notice','notice_type'=>'group_msg_emoji_like','message_id'=>target.external_id,'is_add'=>active,'likes'=>[{'emoji_id'=>emoji_id,'count'=>1}])
  end
  def claim(token) = message([{'type'=>'at','data'=>{'qq'=>@base['self_id']}},{'type'=>'text','data'=>{'text'=>token}}])
end
