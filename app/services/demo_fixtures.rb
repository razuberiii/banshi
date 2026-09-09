require 'cgi'
class DemoFixtures
  TITLES=['周一的精神状态','我宣布今天提前下班','需求没有变，只是全部重写','地铁上的沉默高手','这是一个成熟的文件夹','老板说简单改一下','人类最后的倔强','代码能跑就不要动','电子榨菜补货通知','我与闹钟的长期战争','非常稳定地不稳定','原来大家都一样','好消息：没有坏消息','今天也是互联网考古人','这个群还没有睡','猫比我更懂项目管理','经过严谨的胡说八道','退一步越想越气','这不是重复，是传承','一个截图的奇妙漂流'].freeze
  LINES=[['我：今晚一定早睡','凌晨两点的我：','这条看完就睡。'],['这个问题非常简单。','简单到我们开了','三个小时的会。'],['正在加载情绪…','加载失败。','请先吃饭再试。'],['文件夹叫「最终版」','里面还有八个','「真的最终版」。'],['需求：简单改一下','影响范围：','整个太阳系。'],['群友：有人在吗','五分钟后：','已读空气。'],['生活给了我柠檬','我转发到群里','让大家一起酸。'],['猫：已阅。','猫：不改。','猫：先睡了。']].freeze
  def self.image_bytes(index:,title:nil)
    rng=Random.new(index*971+137)
    palettes=[['#eee8d9','#292c27','#b7442b'],['#c8dddf','#264449','#f8f6ee'],['#dce3d0','#3e5540','#eee7d0'],['#292e37','#f2eedb','#e7c35e'],['#e9d8cd','#6a4339','#faf7ef'],['#eee7b5','#57572d','#bf4e36']]
    bg,ink,accent=palettes[index%palettes.length]
    lines=LINES[index%LINES.length];angle=rng.rand(-9..9)
    shape=case index%4
      when 0 then "<circle cx='510' cy='115' r='75' fill='#{accent}' opacity='.55'/><rect x='32' y='35' width='130' height='90' fill='#{accent}' transform='rotate(#{angle} 50 50)'/>"
      when 1 then "<path d='M0 270 Q180 180 310 300 T700 300 V460 H0Z' fill='#{accent}' opacity='.7'/><circle cx='550' cy='95' r='57' fill='#{ink}' opacity='.12'/>"
      when 2 then "<rect x='45' y='35' width='520' height='380' fill='none' stroke='#{ink}' stroke-width='2'/><path d='M410 0 L640 210 L640 0Z' fill='#{accent}'/>"
      else "<circle cx='510' cy='295' r='170' fill='#{accent}' opacity='.22'/><path d='M40 390 L110 350 L150 405 L215 360' fill='none' stroke='#{accent}' stroke-width='15'/>"
    end
    svg="<svg xmlns='http://www.w3.org/2000/svg' width='640' height='460'><rect width='640' height='460' fill='#{bg}'/>#{shape}<text x='45' y='54' fill='#{ink}' font-family='DejaVu Sans' font-size='12' letter-spacing='3'>INTERNET FIELD NOTES · #{format('%03d',index)}</text>"
    lines.each_with_index { |line,i|svg << "<text x='#{45+(index%3)*10}' y='#{175+i*66}' fill='#{ink}' font-family='Noto Sans CJK SC, sans-serif' font-size='#{i==1 ? 41 : 32}' font-weight='#{i==1 ? 700 : 400}'>#{CGI.escapeHTML(line)}</text>" }
    svg << "<line x1='45' y1='372' x2='590' y2='372' stroke='#{ink}' opacity='.25'/><text x='45' y='403' fill='#{ink}' font-family='Noto Sans CJK SC, sans-serif' font-size='14'>虚构群聊标本 / #{CGI.escapeHTML(title || TITLES[index%TITLES.length])}</text><text x='45' y='427' fill='#{ink}' font-family='DejaVu Sans' font-size='10' opacity='.55'>BANSHI ARCHIVE — ORIGINAL SAFE FIXTURE / #{index}</text></svg>"
    Vips::Image.svgload_buffer(svg).write_to_buffer('.png')
  end
  def self.fresh_asset(index:)
    rng=Random.new(index*7919)
    blocks=Array.new(30) { |i| "<rect x='#{(i%6)*110}' y='#{(i/6)*100}' width='110' height='100' fill='hsl(#{rng.rand(360)},#{rng.rand(25..55)}%,#{rng.rand(30..80)}%)'/>" }.join
    svg="<svg xmlns='http://www.w3.org/2000/svg' width='640' height='460'>#{blocks}<rect x='75' y='140' width='490' height='190' rx='3' fill='white' opacity='.95'/><text x='108' y='195' font-family='sans-serif' font-size='20' fill='#777'>NEW EXCAVATION / #{index}</text><text x='108' y='251' font-family='Noto Sans CJK SC, sans-serif' font-size='35' fill='#252c27'>互联网今天又怎么了</text><text x='108' y='295' font-family='Noto Sans CJK SC, sans-serif' font-size='16' fill='#777'>项目原创虚构标本 · 安全示例</text></svg>"
    Media::ContentIngestor.store(bytes:Vips::Image.svgload_buffer(svg).write_to_buffer('.png'))
  end
  def self.forward_content(index:)
    lines=LINES[index%LINES.size]+["虚构转发标本 #{index}：今天的群聊也很有精神。"]
    content=Content.create!(kind:'forward',fingerprint:Digest::SHA256.hexdigest(JSON.generate(['forward',[],lines])),metadata:{fixture:true})
    lines.each_with_index { |line,i|content.forward_nodes.create!(position:i,display_name:'匿名群友',body:line,sent_at:Time.current) }
    content
  end
end
