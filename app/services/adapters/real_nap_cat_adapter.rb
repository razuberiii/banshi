require 'net/http'
require 'base64'
module Adapters
  # HTTP actions + shared webhook/reverse-WS normalizer; all product decisions remain outside this class.
  class RealNapCatAdapter < OneBotAdapter
    def initialize(connection) = @connection = connection
    def get_login_info = action('get_login_info')
    def get_group_list = action('get_group_list')
    def get_group_info(group_external_id:) = action('get_group_info',group_id:group_external_id)
    def get_group_member_info(group_external_id:,user_external_id:) = action('get_group_member_info',group_id:group_external_id,user_id:user_external_id,no_cache:true)
    def get_bot_card(group_external_id:) = get_group_member_info(group_external_id:group_external_id,user_external_id:@connection.bot_account.external_id).fetch('card','')
    def get_forward(forward_id:) = action('get_forward_msg',message_id:forward_id).fetch('messages')
    def get_message(message_external_id:) = action('get_msg',message_id:message_external_id)
    def set_bot_card(group:,card:) = action('set_group_card',group_id:group.external_id,user_id:@connection.bot_account.external_id,card:card)
    def send_content(group:,entry:,kind:,idempotency_key:)
      intro = entry.sid
      intro += ' · Early' if kind == 'BOT_TRIAL'
      if entry.content.forward?
        nodes=Media::ForwardStructure.onebot_nodes(entry.content,bot_external_id:@connection.bot_account.external_id) { |asset|image_data(asset) }
        nodes.unshift({'type'=>'node','data'=>{'nickname'=>'Banshi','user_id'=>@connection.bot_account.external_id,'content'=>[{'type'=>'text','data'=>{'text'=>intro}}]}})
        send_action('send_group_forward_msg',{group_id:group.external_id,messages:nodes})
      else
        segments=[{'type'=>'text','data'=>{'text'=>intro}}]
        entry.content.assets.each do |asset|
          segments << {'type'=>'image','data'=>image_data(asset)}
        end
        send_action('send_group_msg',{group_id:group.external_id,message:segments})
      end
    end
    private
    def image_data(asset)
      raise RemoteError,'资源已隐藏' unless asset.visibility=='visible'
      bytes=Storage::Registry.current.read(key:asset.storage_key)
      {'file'=>"base64://#{Base64.strict_encode64(bytes)}"}
    end
    def send_action(name,params)
      data=action(name,params,sending:true)
      receipt=data.is_a?(Hash) && data['message_id']
      raise AmbiguousDelivery,'NapCat accepted the request but returned no usable message receipt' unless receipt.is_a?(String) || receipt.is_a?(Integer)
      raise AmbiguousDelivery,'NapCat returned an empty message receipt' if receipt.to_s.empty?
      receipt.to_s
    end
    def action(name,params={},sending:false,**kwargs)
      request_started=false
      raise RemoteError,'真实 NapCat 连接未启用' unless AppConfig.napcat.enabled
      base=@connection.endpoint.presence || AppConfig.napcat.http_url
      uri=URI.join(base.end_with?('/') ? base : "#{base}/",name)
      raise RemoteError,'NapCat endpoint must be HTTP(S)' unless %w[http https].include?(uri.scheme)
      request=Net::HTTP::Post.new(uri);request['Authorization']="Bearer #{@connection.access_token}"
      request['Content-Type']='application/json';request.body=(params.merge(kwargs)).to_json
      timeout=AppConfig.napcat.request_timeout
      response=Net::HTTP.start(uri.host,uri.port,use_ssl:uri.scheme=='https',open_timeout:timeout,read_timeout:timeout,write_timeout:timeout) do |http|
        request_started=true
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        explicit_rejection=(400..499).cover?(response.code.to_i) && response.code.to_i!=408
        raise(sending && !explicit_rejection ? AmbiguousDelivery : RemoteError,"NapCat HTTP #{response.code}")
      end
      json=JSON.parse(response.body)
      unless json.is_a?(Hash) && json['status']=='ok' && [0,'0'].include?(json['retcode'])
        explicit_rejection=json.is_a?(Hash) && json['status']=='failed' && json['retcode'].to_s.match?(/\A-?[1-9][0-9]*\z/)
        raise(sending && !explicit_rejection ? AmbiguousDelivery : RemoteError,'NapCat did not return a definitive success response')
      end
      json['data'] || {}
    rescue RemoteError,AmbiguousDelivery
      raise
    rescue StandardError=>error
      # Once request transmission may have begun, parsing, socket and write
      # failures cannot prove QQ did not receive the message.
      raise(sending && request_started ? AmbiguousDelivery : RemoteError,error.message)
    end
  end
end
