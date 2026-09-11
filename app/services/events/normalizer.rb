require 'digest'
require 'json'
require_relative 'envelope'
module Events
  class Normalizer
    CLAIM_PATTERN = /\bCLAIM-[A-Z0-9]{6,32}\b/.freeze
    def self.call(payload, bot_external_id:) = new(payload, bot_external_id).call
    # Raw events are useful for debugging, but command credentials must never
    # be retained in raw JSON, normalized metadata, or archived message text.
    def self.redact(value)
      case value
      when Hash then value.transform_values { |item| redact(item) }
      when Array
        text=value.filter_map do |item|
          next unless item.is_a?(Hash) && item['type']=='text'
          item.dig('data','text') || item['text']
        end.join
        command=text.match?(CLAIM_PATTERN)
        value.map do |item|
          sanitized=redact(item)
          if command && item.is_a?(Hash) && item['type']=='text'
            if sanitized['data'].is_a?(Hash)
              sanitized['data']['text']='[claim redacted]'
            else
              sanitized['text']='[claim redacted]'
            end
          end
          sanitized
        end
      when String then value.gsub(CLAIM_PATTERN, '[claim redacted]')
      else value
      end
    end
    def initialize(payload, bot_external_id)
      @p, @bot = payload, bot_external_id.to_s
      @base = {event_id: "notice:#{Digest::SHA256.hexdigest(JSON.generate(payload))}",event_type:'UnsupportedEvent', group_external_id: payload['group_id']&.to_s, sender_external_id:payload['user_id']&.to_s, message_external_id:payload['message_id']&.to_s, occurred_at:Time.at(Integer(payload.fetch('time',Time.now.to_i))), reply_to_message_id:nil,content_type:nil,media_references:[],metadata:{}}
    end
    def call
      return message if %w[message message_sent].include?(@p['post_type']) && @p['message_type']=='group'
      return reactions if @p['post_type']=='notice' && @p['notice_type']=='group_msg_emoji_like'
      if @p['notice_type']=='group_card' && @p['user_id'].to_s==@bot
        return [envelope(event_type:'BotGroupCardChanged',metadata:{'card'=>@p['card_new'].to_s})]
      end
      if %w[group_admin group_increase group_decrease].include?(@p['notice_type'])
        return [envelope(event_type:'GroupMemberChanged',metadata:{'change'=>@p['notice_type'],'sub_type'=>@p['sub_type'],'is_bot'=>@p['user_id'].to_s==@bot})]
      end
      if @p['notice_type']=='group_name'
        return [envelope(event_type:'GroupMetadataChanged',metadata:{'name'=>@p['name'].to_s})]
      end
      [envelope(metadata:{'unsupported'=>@p['notice_type']||@p['post_type']})]
    end
    private
    def envelope(**attrs) = Envelope.new(**@base.merge(attrs))
    def message
      segments=@p['message'].is_a?(Array) ? @p['message'] : [{'type'=>'text','data'=>{'text'=>@p['message'].to_s}}]
      images=segments.select { |s| s['type']=='image' }
      forwards=segments.select { |s| %w[forward node].include?(s['type']) }
      text=segments.select { |s| s['type']=='text' }.map { |s| s.dig('data','text') }.join
      reply=segments.find { |s| s['type']=='reply' }&.dig('data','id')&.to_s
      mentioned_ids=segments.select { |s| s['type']=='at' }.map { |s| s.dig('data','qq').to_s }.uniq
      mentions=mentioned_ids.include?(@bot)
      kind=forwards.any? ? 'forward' : images.any? ? 'image' : 'text'
      references=(kind=='forward' ? segments : images).filter_map do |segment|
        data=segment['data'] || {}
        case segment['type']
        when 'image' then {'type'=>'image','url'=>data['url'],'file'=>data['file']}
        when 'text' then {'type'=>'text','text'=>data['text'].to_s}
        when 'forward' then {'type'=>'forward','forward_id'=>data['id'],'nodes'=>data['content']}
        when 'node' then {'type'=>'node','nodes'=>[data]}
        end
      end
      token=text[CLAIM_PATTERN]
      [envelope(event_id:"message:#{@base[:group_external_id]}:#{@base[:message_external_id]}",event_type:{'image'=>'ImageMessageReceived','forward'=>'ForwardMessageReceived','text'=>'GroupMessageReceived'}.fetch(kind),content_type:kind,reply_to_message_id:reply,media_references:self.class.redact(references),metadata:{'text'=>self.class.redact(text),'mentions_bot'=>mentions,'mentioned_external_ids'=>mentioned_ids,'claim_digest'=>token && Digest::SHA256.hexdigest(token),'quote'=>segments.any? { |s| s['type']=='reply' },'sender_card'=>self.class.redact(@p.dig('sender','card'))})]
    end
    def reactions
      unless @p['user_id'] && @p['user_id'].to_s!='0' && [true,false].include?(@p['is_add'])
        return [envelope(metadata:{'unsupported'=>'reaction_identity_or_action_unknown'})]
      end
      Array(@p['likes']).map do |like|
        emoji=like['emoji_id'].to_s
        envelope(event_id:"#{@base[:event_id]}:#{emoji}",event_type:'ReactionReceived',metadata:{'emoji_id'=>emoji,'active'=>@p['is_add']})
      end
    end
  end
end
