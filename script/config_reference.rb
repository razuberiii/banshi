#!/usr/bin/env ruby
# Generate checked-in configuration references without booting Rails or a DB.
require 'json'
root=File.expand_path('..',__dir__)
schema=JSON.parse(File.read(File.join(root,'config/app_config_schema.json')))
env=["# 搬💩 v0.1 · 复制为 .env 后使用；所有键由 AppConfig 统一解析。",
     "# 开发默认值。生产环境必须关闭 DEMO_ENABLED / SEED_DEMO 并更换密钥。",'']
doc=["# 统一配置参考",'',
     '配置优先级：代码默认值 → ENV → 群数据库偏好。群偏好只覆盖胃口、摄入量、冷却等群设置，不能突破 RED 或平台硬标签。','',
     '`config/app_config.rb` 集中处理类型、默认值和启动校验。时间单位转换为秒，业务使用 `AppConfig.section.key`。更换来源时修改 `AppConfig.load(source)`。','',
     '此文件和 `.env.example` 由 `ruby script/config_reference.rb` 生成，新增配置后请重新运行。','']
schema.each do |section,entries|
  env << "# #{section.upcase}"
  doc.concat(["## #{section}",'','| ENV | AppConfig | 类型 / 输入单位 | 默认值 |','| --- | --- | --- | --- |'])
  entries.each do |key,(name,type,default)|
    value=case default
      when Hash,Array then "'#{JSON.generate(default)}'"
      when String then default.match?(/\s/) ? JSON.generate(default) : default
      else default.to_s
    end
    env << "#{name}=#{value}"
    displayed=case default
      when Hash,Array then JSON.generate(default)
      else default.to_s
    end
    displayed='空' if displayed.empty?
    displayed='开发专用占位密钥；生产必须替换' if name=='SECRET_KEY_BASE'
    doc << "| `#{name}` | `#{section}.#{key}` | #{type} | #{displayed.gsub('|','\\|')} |"
  end
  env << '';doc << ''
end
File.write(File.join(root,'.env.example'),env.join("\n")+"\n")
File.write(File.join(root,'docs/configuration.md'),doc.join("\n")+"\n")
puts "Generated #{schema.values.sum(&:length)} configuration keys."
