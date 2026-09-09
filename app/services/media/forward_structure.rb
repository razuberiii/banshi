require 'digest'
require 'json'

module Media
  # Images reference attachment positions, so a later redaction changes the
  # bytes used by every serializer without leaving stale original asset IDs.
  module ForwardStructure
    def self.tree(content)
      stored=content.metadata['forward_tree']
      return stored if stored.is_a?(Array)

      rows=content.forward_nodes.order(:position).to_a
      children=rows.group_by(&:parent_id)
      positions=content.attachments.order(:position).to_a.each_with_object({}) { |attachment,index|index[attachment.asset_id] ||= attachment.position }
      visited=[]
      build=lambda do |parent_id|
        Array(children[parent_id]).map do |node|
          raise ArgumentError,'转发节点存在循环' if visited.include?(node.id)
          visited << node.id
          segments=[]
          segments << {'type'=>'text','text'=>node.body.to_s} unless node.body.to_s.empty?
          if node.asset_id
            reference=positions.key?(node.asset_id) ? {'attachment_position'=>positions.fetch(node.asset_id)} : {'asset_id'=>node.asset_id}
            segments << {'type'=>'image'}.merge(reference)
          end
          nested=build.call(node.id)
          segments << {'type'=>'forward','nodes'=>nested} unless nested.empty?
          {'segments'=>segments,'time'=>node.sent_at&.to_i}
        end
      end
      result=build.call(nil)
      raise ArgumentError,'转发节点父级不属于本内容或存在循环' unless visited.length==rows.length
      result
    end

    def self.asset_for(content,segment)
      if segment.key?('attachment_position')
        content.attachments.find_by!(position:segment.fetch('attachment_position')).asset
      else
        # Compatibility with directly authored ForwardNode rows that do not
        # have a matching top-level attachment.
        content.forward_nodes.find_by!(asset_id:segment.fetch('asset_id')).asset
      end
    end

    def self.canonical(tree,assets:)
      tree.map do |node|
        node.fetch('segments').map do |segment|
          case segment.fetch('type')
          when 'text' then ['text',segment.fetch('text')]
          when 'image'
            asset=segment.key?('attachment_position') ? assets.fetch(segment.fetch('attachment_position')) : assets.find { |item|item.id==segment.fetch('asset_id') }
            raise ArgumentError,'转发图片没有对应资源' unless asset
            ['image',asset.sha256]
          when 'forward' then ['forward',canonical(segment.fetch('nodes'),assets:assets)]
          else raise ArgumentError,'未知转发内容段'
          end
        end
      end
    end

    def self.fingerprint(tree,assets:)
      normalized=canonical(tree,assets:assets)
      # Existing seeds and flat text-only archives keep their original exact
      # hashes. Rich forwards include topology and per-node image placement.
      value=if normalized.all? { |node|node.all? { |segment|segment.first=='text' } }
        ['forward',[],normalized.map { |node|node.map(&:last).join }]
      else
        ['forward-v2',normalized]
      end
      Digest::SHA256.hexdigest(JSON.generate(value))
    end

    # With bot_external_id, return outbound node segments. Without it, return
    # get_forward_msg-style received nodes, including inline nested forwards.
    def self.onebot_nodes(content,bot_external_id:nil,&image_data)
      render=lambda do |nodes|
        nodes.map do |node|
          segments=node.fetch('segments').flat_map do |segment|
            case segment.fetch('type')
            when 'text' then [{'type'=>'text','data'=>{'text'=>segment.fetch('text')}}]
            when 'image' then [{'type'=>'image','data'=>image_data.call(asset_for(content,segment))}]
            when 'forward'
              nested=render.call(segment.fetch('nodes'))
              bot_external_id ? nested : [{'type'=>'forward','data'=>{'content'=>nested}}]
            else raise ArgumentError,'未知转发内容段'
            end
          end
          if bot_external_id
            # NapCat requires an array containing node segments to contain
            # only nodes. Wrap adjacent ordinary segments as anonymous child
            # nodes at the wire boundary, preserving their position and bytes.
            if segments.any? { |segment|segment['type']=='node' }
              grouped=[]
              ordinary=[]
              flush=lambda do
                unless ordinary.empty?
                  grouped << outbound_node(ordinary,bot_external_id)
                  ordinary=[]
                end
              end
              segments.each do |segment|
                if segment['type']=='node'
                  flush.call
                  grouped << segment
                else
                  ordinary << segment
                end
              end
              flush.call
              segments=grouped
            end
            outbound_node(segments,bot_external_id)
          else
            {'nickname'=>'匿名群友','content'=>segments,'time'=>node['time']}
          end
        end
      end
      render.call(tree(content))
    end

    def self.outbound_node(segments,bot_external_id)
      {'type'=>'node','data'=>{'nickname'=>'匿名群友','user_id'=>bot_external_id,'content'=>segments}}
    end
    private_class_method :outbound_node
  end
end
