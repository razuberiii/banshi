require 'net/http'
require 'digest'
module Media
  class ContentIngestor
    def self.call(event:, adapter:) = new(event,adapter).call
    def initialize(event,adapter)
      @event,@adapter=event,adapter
      @assets=[]
      @node_count=0
    end
    def call
      return nil unless %w[image forward].include?(@event.content_type)
      tree=[]
      if @event.content_type=='image'
        @event.media_references.each { |reference|image_segment(reference) }
      else
        pending=[]
        flush=lambda do
          unless pending.empty?
            count_node!
            tree << {'segments'=>pending}
            pending=[]
          end
        end
        @event.media_references.each do |ref|
          case ref['type'] || (ref.key?('forward_id') ? 'forward' : 'image')
          when 'image' then pending << image_segment(ref)
          when 'text'
            text=Events::Normalizer.redact(ref['text'].to_s)
            pending << {'type'=>'text','text'=>text} unless text.empty?
          when 'forward'
            flush.call
            tree.concat(expand_forward(ref,depth:0,ancestors:[]))
          when 'node'
            flush.call
            tree.concat(normalize_nodes(ref.fetch('nodes'),depth:0,ancestors:[]))
          end
        end
        flush.call
        raise ArgumentError,'转发没有可存档的内容' if tree.empty?
      end
      signature=@event.content_type=='image' ? Digest::SHA256.hexdigest(JSON.generate(['image',@assets.map(&:sha256),[]])) : ForwardStructure.fingerprint(tree,assets:@assets)
      Content.transaction do
        content=Content.create!(kind:@event.content_type,fingerprint:signature,metadata:tree.empty? ? {} : {'forward_tree'=>tree})
        @assets.each_with_index { |asset,i|content.attachments.create!(asset:asset,position:i) }
        position=0
        persist=lambda do |nodes,parent|
          nodes.each do |node|
            segments=node.fetch('segments')
            image=segments.find { |segment|segment['type']=='image' }
            record=content.forward_nodes.create!(parent:parent,position:position,display_name:'匿名群友',body:segments.select { |segment|segment['type']=='text' }.map { |segment|segment['text'] }.join,asset:image && @assets.fetch(image.fetch('attachment_position')),sent_at:node['time'] ? Time.at(node['time'].to_i) : nil)
            position+=1
            segments.select { |segment|segment['type']=='forward' }.each { |segment|persist.call(segment.fetch('nodes'),record) }
          end
        end
        persist.call(tree,nil)
        content
      end
    end
    def self.store(bytes:, content_type:nil)
      raise ArgumentError,'文件超过接收上限' if bytes.bytesize > AppConfig.napcat.max_media_bytes
      image=Vips::Image.new_from_buffer(bytes,'',access: :sequential)
      raise ArgumentError,'图片像素超过接收上限' if image.width*image.height>AppConfig.napcat.max_media_pixels
      # Store decoded raster only: SVG/HTML and remote active content never reach a browser.
      canonical_type=bytes.start_with?("\x89PNG".b) ? 'image/png' : bytes.start_with?("\xff\xd8".b) ? 'image/jpeg' : 'image/webp'
      unless ['image/png','image/jpeg'].include?(canonical_type)
        bytes=image.write_to_buffer('.webp');canonical_type='image/webp'
      end
      sha=Digest::SHA256.hexdigest(bytes)
      Asset.find_by(sha256:sha) || begin
        hash=AppConfig.features.phash ? PerceptualHash.call(bytes) : nil
        key="#{sha[0,2]}/#{sha}.#{canonical_type.split('/').last}"
        Storage::Registry.current.put(key:key,bytes:bytes,content_type:canonical_type)
        Asset.create_or_find_by!(sha256:sha) { |a|a.assign_attributes(phash:hash,storage_key:key,content_type:canonical_type,byte_size:bytes.bytesize,width:image.width,height:image.height) }
      end
    rescue Vips::Error
      raise ArgumentError,'无法读取图片'
    end
    private
    def count_node!
      @node_count+=1
      raise ArgumentError,'转发节点超过接收上限' if @node_count>AppConfig.napcat.max_forward_nodes
    end
    def image_segment(reference)
      raise ArgumentError,'转发图片超过接收上限' if @assets.length>=AppConfig.napcat.max_forward_media
      asset=resolve_asset(reference)
      @assets << asset
      {'type'=>'image','attachment_position'=>@assets.length-1}
    end
    def expand_forward(reference,depth:,ancestors:)
      id=reference['forward_id'] || reference['id']
      raise ArgumentError,'转发引用存在循环' if id && ancestors.include?(id.to_s)
      inline=reference['nodes'] || reference['content']
      nodes=if inline.is_a?(Array) && !inline.empty?
        inline
      elsif id && !id.to_s.empty?
        @adapter.get_forward(forward_id:id)
      else
        raise ArgumentError,'转发内容缺少有效节点或资源 ID'
      end
      normalize_nodes(nodes,depth:depth,ancestors:id ? ancestors+[id.to_s] : ancestors)
    end
    def normalize_nodes(nodes,depth:,ancestors:)
      raise ArgumentError,'转发嵌套超过接收上限' if depth>AppConfig.napcat.max_forward_depth
      raise ArgumentError,'转发节点格式不正确' unless nodes.is_a?(Array) && !nodes.empty?
      nodes.map do |raw|
        count_node!
        raise ArgumentError,'转发节点格式不正确' unless raw.is_a?(Hash)
        node=raw['type']=='node' ? raw.fetch('data') : raw
        raw_segments=node['content'] || node['message'] || []
        raw_segments=[{'type'=>'text','data'=>{'text'=>raw_segments}}] if raw_segments.is_a?(String)
        raise ArgumentError,'转发内容段格式不正确' unless raw_segments.is_a?(Array)
        raw_segments=Events::Normalizer.redact(raw_segments)
        segments=raw_segments.filter_map do |segment|
          data=segment['data'] || {}
          case segment['type']
          when 'text'
            text=Events::Normalizer.redact(data['text'].to_s)
            {'type'=>'text','text'=>text} unless text.empty?
          when 'image' then image_segment(data)
          when 'forward' then {'type'=>'forward','nodes'=>expand_forward(data,depth:depth+1,ancestors:ancestors)}
          when 'node' then {'type'=>'forward','nodes'=>normalize_nodes([segment],depth:depth+1,ancestors:ancestors)}
          when 'at' then {'type'=>'text','text'=>data['qq'].to_s=='all' ? '@全体群友' : '@匿名群友'}
          when 'face' then {'type'=>'text','text'=>"[QQ 表情 #{Integer(data.fetch('id'))}]"}
          when 'reply' then {'type'=>'text','text'=>'[引用消息]'}
          else raise ArgumentError,"转发包含暂不支持的内容段：#{segment['type']}"
          end
        end
        raise ArgumentError,'转发节点没有可存档内容' if segments.empty?
        {'segments'=>segments,'time'=>node['time'] ? node['time'].to_i : nil}
      end
    end
    def resolve_asset(ref)
      file=ref['file'].to_s
      if file.start_with?('fake://')
        raise ArgumentError,'非模拟连接不能使用本地资源' unless @adapter.is_a?(Adapters::FakeNapCatAdapter)
        return Asset.find(Integer(file.delete_prefix('fake://')))
      end
      uri=URI(ref['url'].presence || file)
      unless uri.scheme=='https' && AppConfig.napcat.media_allowed_hosts.include?(uri.host) && uri.userinfo.nil? && [nil,443].include?(uri.port)
        raise ArgumentError,'媒体来源不在允许列表'
      end
      bytes=''.b
      Net::HTTP.start(uri.host,uri.port,use_ssl:true,open_timeout:AppConfig.napcat.request_timeout,read_timeout:AppConfig.napcat.request_timeout) do |http|
        http.request_get(uri.request_uri) do |response|
          raise ArgumentError,'媒体下载失败（不跟随重定向）' unless response.is_a?(Net::HTTPSuccess)
          response.read_body do |chunk|
            bytes << chunk
            raise ArgumentError,'文件超过接收上限' if bytes.bytesize>AppConfig.napcat.max_media_bytes
          end
        end
      end
      self.class.store(bytes:bytes)
    end
  end
end
