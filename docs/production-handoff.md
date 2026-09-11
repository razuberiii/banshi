# Banshi production and QQ login

Banshi 的主流程为 Collector → Candidate → 去重/S-ID → Safety → Distributor → Delivery/Occurrence → QQ feedback。默认不等待 Trial 通过。没有 AI 分类或推荐。

## 部署

保留现有服务和反向代理。网站默认只绑定 `127.0.0.1:3300`；NapCat WebUI 只绑定 `127.0.0.1:6099`，HTTP 3000 与 WS 3001 仅在 Docker 网络中可见。Docker Engine 与 Compose 必须已安装，当前操作账号需要使用权限。

在仓库目录运行一次初始化（已有配置会拒绝覆盖）：

```bash
bin/prepare-production /opt/stacks/napcat-banshi
docker network create banshi-napcat
docker compose -f /opt/stacks/napcat-banshi/compose.yaml up -d
docker compose -f compose.production.yaml up -d --build
```

网络已存在时跳过 create。`.env.production` 为本机生成的私密文件，不提交；NapCat 独立目录保留会话卷、配置、cache 和日志。镜像默认使用官方当前 `mlikiowa/napcat-docker:latest` 多架构标签，拉取成功后应将其 RepoDigest 写入 NapCat 目录 `.env` 的 `NAPCAT_IMAGE` 固定版本，避免未来意外更新。启动前检查 `uname -m`；官方支持 amd64/arm64。

Rails 首次启动执行 db:prepare 与 db:seed；生产 `SEED_DEMO=false` 不创建虚构数据。worker、bridge、数据库和 NapCat 均配置 `unless-stopped`。Docker daemon 本身须由服务器开机启动。挂载卷应纳入备份；不要用 `down -v` 删除会话或数据库。

若网站通过域名访问，将域名加入 `.env.production` 的 `ALLOWED_HOSTS`；反向代理指向 `127.0.0.1:3300`，TLS 代理环境使用 `FORCE_SSL=true`。不要替换其他项目的 Nginx 配置。

## 用户扫码

在自己的电脑建立 SSH 隧道（替换已有 SSH 用户和服务器地址）：

```bash
ssh -N -L 6099:127.0.0.1:6099 -L 3300:127.0.0.1:3300 SSH_USER@SERVER
```

打开网站 `http://localhost:3300`，NapCat WebUI `http://localhost:6099/webui`。

WebUI Token 在服务器 NapCat 目录 `config/webui.json` 的 `token` 字段。本机终端安全读取即可，不要复制到 Git、网页或工单。也可以在自己的终端查看 NapCat 启动日志；官方启动日志可能包含 Token，不要公开整份日志。

登录 WebUI 后用手机 QQ 扫描其中的二维码并确认。无需提供 QQ 密码，不需要修改代码。NapCat 启动 OneBot 服务，bridge 自动识别账号与群列表；此后群消息进入 Collector。首次登录会从 `onebot11.json` 继承连接配置并生成账号配置文件，重建容器继续使用持久化会话。

## 确认状态

维护者登录网站后访问 `/system/status`，查看 Rails、数据库、worker、NapCat、Bot QQ、连接群数、候选、投递队列与最近事件。首次创建维护者账号可在服务器执行 `docker compose -f compose.production.yaml exec web bundle exec ruby bin/create-curator`；维护者登录不影响 Bot 的自动运行。

无需网站账号的本机诊断：

```bash
docker compose -f compose.production.yaml ps
docker compose -f compose.production.yaml exec web bin/rails runner 'puts BotConnection.where(adapter: "real").pluck(:name, :status, :last_seen_at).inspect'
docker compose -f compose.production.yaml exec web bin/rails runner 'puts GroupBotMembership.where(active: true).distinct.count(:group_id)'
docker compose -f compose.production.yaml logs -f web worker bridge
docker compose -f /opt/stacks/napcat-banshi/compose.yaml logs -f napcat
```

NapCat 未登录时 API 可能尚未监听，bridge 记录 waiting_login 并重试。这是待登录/连接状态，不会把账号伪造为 online。会话失效后重新扫码即可。

## 开关与反馈

编辑 `.env.production`：`DISTRIBUTION_ENABLED=false` 暂停主动投放；恢复设为 true。随后 `docker compose -f compose.production.yaml up -d --force-recreate web worker bridge` 应用环境变量。发送前会再次检查开关。

默认每轮 3 群、每群每日 6 条、冷却 60 分钟、下一轮至少等待 15 分钟。首轮不要求反馈；后续需要累计至少 1 个正 Reaction、reply/quote 或自然再次出现信号，且明确负反馈不占优。沉默保留 unknown。`DISTRIBUTION_MIN_FEEDBACK=0` 可允许未知表现继续扩散。所有参数均经 AppConfig 读取，见 [配置参考](configuration.md)。

`TRIAL_ENABLED=true` 与 `TRIAL_REQUIRED_BEFORE_DISTRIBUTION=false` 是默认组合。可选 Trial 只选择 OPT_IN 群，不阻塞普通首轮，也不会因沉默将活跃条目降级。机器人文案为 S-ID，Trial 增加 `· Early`。

多实例示例（Token 分别在本机 ENV 中配置，以下不含真实值）：

```dotenv
NAPCAT_CONNECTIONS='{"primary":{"http_url":"http://napcat:3000","ws_url":"ws://napcat:3001"},"second":{"http_url":"http://napcat-second:3000","ws_url":"ws://napcat-second:3001"}}'
NAPCAT_CONNECTION_TOKENS='{"primary":"REPLACE_LOCALLY","second":"REPLACE_LOCALLY"}'
```

每个实例必须有独立持久目录与网络别名。Group 保持独立，Distributor 自动选择在线 Bot 通道。

## 验证边界

CI 同时执行 Ruby 单元/集成测试与 Docker production smoke：实际构建 Rails 镜像、启动 PostgreSQL/worker/bridge，并检查官方 NapCat 未登录 WebUI。CI 的容器验证不代表目标服务器已经部署。

`docker compose exec web bin/verify` 验证开发 Fake stack。生产镜像也可使用独立 TEST_DATABASE_URL 执行同一套测试；运行时应设置 `RAILS_ENV=test`，避免生产环境配置污染测试。

发布不能仅凭配置文件声称已部署。必须实际检查容器、WebUI、网络、未登录稳定性与 CI。真实 QQ 采集/发送/Reaction 需要扫码后的现场验证；旧版本 Reaction 缺失 actor 或 is_add 时会被忽略，不能伪造投票。

官方依据： [NapCat Docker](https://github.com/NapNeko/NapCat-Docker)、[NapCatQQ](https://github.com/NapNeko/NapCatQQ)、[OneBot 11](https://github.com/botuniverse/onebot-11)。本轮核对 NapCatQQ commit `109d0c1dff755875f3b79795e99cee6115289fbb` 的配置 schema、账号默认配置继承、get_login_info、get_group_list、get_forward_msg 与 group_msg_emoji_like 事件；这属于源码核对，不是 QQ 在线验收。

## rubusoo.com 服务器（2026-09-11）

本机已真实运行 `/opt/stacks/banshi`（指向仓库）和 `/opt/stacks/napcat-banshi`。Docker 开机启动，PostgreSQL、Rails、GoodJob、bridge、NapCat 均为 `unless-stopped`；已验证 Rails 重启和 NapCat 容器重建。旧原生 PostgreSQL 数据已备份至 `/opt/stacks/banshi-backups`，生产数据库无模拟内容。

网站域名为 `banshi.rubusoo.com`。部署时 Let’s Encrypt 对本域名及现有域名的二次 DNS 校验均返回 networking error，公网 HTTP challenge 本身可达。当前 HTTP 仅开放公开读取，登录/注册/维护入口及写操作关闭；某些浏览器自动升级 HTTPS 后会暂时看到 Cloudflare 525。不能把此状态视为 HTTPS 已完成。

服务器 `banshi-https.timer` 每小时重试。证书成功签发后，root-owned `/usr/local/sbin/banshi-enable-https` 自动安装独立 Nginx HTTPS 配置并停止此重试 timer；之后由现有 certbot.timer 正常续期。模板在 `deploy/nginx`，不修改其他站点。检查实时状态：

```bash
sudo systemctl list-timers banshi-https.timer
sudo journalctl -u banshi-https.service -n 30
curl -I https://banshi.rubusoo.com
```

在证书恢复前，可通过 SSH 隧道访问 `http://localhost:3300` 检查网站；WebUI 始终使用 `http://localhost:6099/webui`。QQ 登录和自动采集/分发不依赖公网证书。WebUI Token 的安全读取命令（在自己的 SSH 终端运行，不把输出分享出去）：

```bash
python3 -c 'import json; print(json.load(open("/opt/stacks/napcat-banshi/config/webui.json"))["token"])'
```

本机生产镜像已执行 `bin/verify`：127 tests / 854 assertions，零失败。GoodJob 维护任务实际执行成功，私有网络可达 NapCat WebUI；经 WebUI 鉴权查询确认 `isLogin=false` 且二维码可用。未登录时 OneBot HTTP/WS 尚未监听是 NapCat 当前行为，因此真实 QQ API 发送/收取仍必须在扫码后验证。
