# v0.1 验证记录

验证日期：2026-09-09。这里区分已经执行的检查与尚未运行的外部集成，不把配置文件存在当作部署验收。

## 已执行

| 检查 | 实际结果 |
| --- | --- |
| 全部自动测试 | **119 runs, 822 assertions, 0 failures, 0 errors, 0 skips** |
| Rails 自动加载 | `rails zeitwerk:check` 返回 `All is good!` |
| 数据库迁移 | 5 份 migration 全部执行成功，包括领域表、GoodJob、模拟动作、事件顺序字段和显式群开关升级 |
| 资源构建 | `rails assets:clobber` 后 `rails assets:precompile` 成功 |
| JavaScript 语法 | `node --check app/assets/javascripts/application.js` 成功 |
| Seed | 初始产生 24 群、36 搬运者、120 条目、1,285 条 Occurrence；再次 seed 保留已有历史 |
| 实际 HTTP | Puma 启动后，请求存活检查、首页、目录、条目、群详情、搬运者、试吃、排行榜、搜索，9 个 URL 均为 200 |
| 独立后台进程 | `good_job start` 启动 scheduler 和 LISTEN，消费预先持久化的 ReputationRefreshJob，成功写入 finished_at、error=nil，随后正常退出 |
| 完整终端模拟 | 图像 → Candidate → 3 人回复 → accepted → 人工安全审核 → 5 群 Trial → NORMAL → 普通传播 → 相同 S-ID 自然复读 → 90 天后 CLASSIC |
| 原生媒体库 | libvips 执行真实 pHash 与图片转换；同时验证 Nokogiri HTML5 XPath，修复二者 libxml 加载顺序冲突 |
| 前端排版 | 11 个 Rails 数据库页面成功渲染 HTML；首页在 1440 / 390 宽度进行离线排版、导出并检查图片 |
| 交付结构 | Compose YAML、启动脚本执行权限和 `git diff --check` 检查 |

本次终端模拟建立 `S-000133`，送达 5 个试吃群，试吃通过后保留同一个编号进入 NORMAL，再按自然生命周期成为 CLASSIC。编号来自数据库序列；干净安装时的具体编号可能不同。

测试覆盖候选观察窗口、阈值、冷启动、作者自互动排除、过期、自然重现与机器人区别、回复独立人数、Reaction 幂等 / 撤销 / 乱序、SHA / DCT pHash、合并与撤销、安全硬限制、标签胃口、举报升级与显式恢复、试吃轮换、OPT_OUT、沉默 unknown、配额 / 冷却、HOT / CLASSIC、复活重算、认领一次性与实时角色复核、配置类型与开关、对象存储、Webhook 鉴权、消息 ID 冲突、权限与隐私页面。

默认自助调整追加验证：新群无需认领即参与、未知名片不关闭业务、乱序名片只同步元数据、多机器人改名不覆盖设置、未认领用户无权设置、管理员两开关独立生效。迁移测试实际执行升级 / 回滚，验证空开关变为开启、显式关闭保留、历史 Message 归属不变。

## 数据库验证环境的准确边界

运行环境为 Ruby 3.2.3、Rails 8.0.5.1、GoodJob 4.19.2、libvips 8.15。当前沙箱无法运行 Docker daemon，也无法在其 UID 映射下启动普通 PostgreSQL 服务，因此测试通过 PostgreSQL wire protocol 连接 **PGlite 的 PostgreSQL 18.3 WebAssembly 引擎**。开发库与测试库独立持久化。

这是执行 PostgreSQL SQL、迁移、外键、JSONB、数组、trigram、事务与持久任务的数据库引擎，未用 SQLite 或 Ruby 内存仓库替代。但它**不能等价验证原生 PostgreSQL 的多后端并发、竞争条件或负载表现**。验证适配时关闭 prepared statements，并显式运行测试迁移；项目默认仍为正常 PostgreSQL 配置。

交付的 Compose 使用原生 PostgreSQL 16，GitHub Actions 同样配置 PostgreSQL 16。两者的配置已生成，但**本次没有执行 Docker build / compose up，也没有运行远端 CI**。原生 PostgreSQL 上的复核命令：

```bash
docker compose up --build
docker compose exec web bin/verify
docker compose exec web bin/demo all
docker compose logs -f worker
```

## 浏览器与外部服务

受当前浏览器工具策略限制，localhost 与本地文件导航被拒绝；未绕过限制。页面权限、表单提交、登录、举报、收藏、评价、管理、认领及嵌套转发由 Rails integration tests 验证。静态排版使用 WeasyPrint，对手机尺寸应用项目自身响应式 CSS；[桌面](previews/desktop.png) / [手机](previews/mobile.png) 图片是**离线排版预览，不是浏览器自动化截图**，不能证明 JavaScript、触摸滚动或跨浏览器行为已经人工验收。

NapCat 的真实 HTTP / WebSocket 适配层有协议与传输测试，并附官方能力核查；没有登录真实 QQ。Reaction 身份、增删方向及离线事件丢失必须按部署版本实测。S3CompatibleStorage 有 AWS SDK 请求契约测试，本次未连接真实桶；默认 LocalStorage 已实际读写媒体。

不确定发送保留为 `uncertain`，不会假装成功或盲目重试。需要维护者在 QQ 侧核对回执与实际消息后处理；协议没有服务端幂等键，项目不承诺 exactly-once。
