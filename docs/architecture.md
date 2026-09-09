# 搬💩 v0.1 · 产品与领域约定

目标：可持续运行的 Rails 单体互联网群聊档案馆。用户完整 60 节规格为范围依据，真实 QQ 连接是唯一模拟的外部环节。用户授权自行决定常规设计，不设置设计确认等待。

## 运行形态
Rails 8.0 + PostgreSQL 16+ + GoodJob (同一 PostgreSQL、独立 worker、定时调度)；ERB 服务端渲染、少量原生渐进增强 JS。开发与 Docker 共用一套业务代码。Ruby 3.2+ 兼容，容器 Ruby 3.3。Local / S3 对象存储统一接口。业务配置仅经 AppConfig，群级配置保存数据库。新群默认同时采集与接收传播，两个显式布尔开关由认领后的管理员在网站设置；名片仅为 Bot 资料，不参与业务决策。

## 领域边界
OneBot raw payload → RawEvent → InternalEvent → EventProcessor。Collector 只做建档规则；Safety 负责安全级别、标签、可展示和可传播；Distributor 在每次发出前重新调用 Safety 和 GroupMatcher。Group 与 Bot 独立，以 GroupBotMembership 找可用 BotConnection。Content + Asset + Attachment 支持多资产和 ForwardNode。

Candidate 窗口默认30分钟，到期结算；强信号独立参与者，作者本人不计；信誉贝叶斯平滑中性冷启动且不能单独使候选入库。SHA 自动确认；DCT pHash 低距离且内容形态相符可确认，中间区间标 possible，人工合并可撤销。Natural 与 BOT_TRIAL/BOT_DISTRIBUTION/BOT_CLASSIC 单独统计。S-ID 由数据库 sequence 生成，不回收。

## 安全与隐私
未知图片默认 RED / 未审核：允许私有元数据存档，不进入公共媒体和自动传播。示例资源经明确 seed safety decision 标 GREEN；不将高热度当审核。YELLOW 需标签集合全部被目标群接受，RED 平台硬禁止。隐私/未成年人举报立即冻结可见媒体，其余达到配置阈值暂停传播。所有原始 QQ 号仅内部使用，网站展示安全别名。群隐藏/仅统计贯穿列表、详情、搜索、时间线、媒体。

## 可靠性
输入事件唯一键及数据库锁；乱序互动按目标消息保留并回补；Reaction 使用最后时间戳及可撤销状态。发出前创建 durable Delivery，Fake 按 key 幂等。真实 OneBot 无 send exactly-once 保证：超时状态为 uncertain，禁止盲重发。所有后台工作 ActiveJob、队列重试与失败记录；定时 sweep 恢复遗失调度。Claim 只存 token digest，短期、原子一次消费、通过适配器实时核验 owner/admin 与 @bot。

## 网站设计
白色馆藏纸张、深墨字、朱红印章、档案编号与石墨方格、石灰黄试吃提示。顶部公开导航，无后台侧栏。首页为展品目录；详情以 S-ID 和资源为主，群为文化馆；管理在群页面内、维护审核在受限馆务页。真实查询生成榜单与时间线；所有交互提供空/失败状态。

## 交付
20+群、30+搬运者、100+条目、2机器人、多种生命周期与失败试吃；可逐步操作 Fake QQ、推进观察窗口、审核、试吃反馈、自然复现及考古。完整测试、运行记录、Docker、ENV、README、可下载源码和完整 Git 历史。目标仓库为 razuberiii/banshi，以独立分支提交 PR。
