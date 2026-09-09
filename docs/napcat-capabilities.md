# NapCat + OneBot 11 能力核查（搬💩 v0.1）

核查日期：2026-09-09。只核查协议能力，不涉及 AI 功能。GitHub 最新稳定版是 [v4.18.19](https://github.com/NapNeko/NapCatQQ/releases/tag/v4.18.19)（2026-08-14）。下面的源码观察固定在 [96de2314b0a82ad6156d92ff4b3921fd46f494c1](https://github.com/NapNeko/NapCatQQ/commit/96de2314b0a82ad6156d92ff4b3921fd46f494c1)（2026-09-08）；Reaction 事件类另外核对了稳定版。**这是文档与源码核查，不是已连接真实 QQ 群的验收结果。**

产品调整（2026-09-09）：以下为协议能力资料。v0.1 新群默认自助餐，名片事件仅同步 Bot 元数据；采集和接收开关只由网站的群设置控制。

## 能力矩阵

| 能力 | 精确入口 / 关键字段 | v0.1 可采用的处理 |
| --- | --- | --- |
| 群消息 | `post_type=message`, `message_type=group`, `sub_type=normal`; `self_id`, `time`, `group_id`, `user_id`, `message_id`, `message`, `raw_message`, `sender`。 | 开启数组消息格式，保存完整原始 payload。`sender.role` 等发送者资料可能缺失或来自旧缓存。[OneBot 消息事件](https://github.com/botuniverse/onebot-11/blob/master/event/message.md) |
| 图片 | 消息段 `type=image`; `data.file`，通常有 `url`，扩展可能有 `file_size`, `sub_type`, `summary`, `file_id`, `path`, `file_unique`。发送 `file` 可用 URL、路径、`base64://` 数据。 | 保留段顺序和多图片；需要长期转发的媒体应及时保存本地副本，不能承诺 QQ URL 永久可用。商城表情也可能作为 image 上报。[消息兼容](https://napneko.github.io/develop/msg)、[段字段](https://napneko.github.io/onebot/segment) |
| 回复 / 引用 | 段 `type=reply`, `data.id` 为被回复消息的 ID（文档类型 string）。 | 从结构化 reply 段找目标；用同一群内已存消息确认关系，必要时调用 `get_msg`。普通文本、昵称、转发中的显示身份不能代替引用关系。[reply 定义](https://napneko.github.io/onebot/segment) |
| 合并转发接收 | 段 `type=forward`, `data.id`; `data.content` 可能已有展开消息。`parseMultMsg` 配置默认 false。 | 未展开时再查询；递归遍历节点设深度、节点数、媒体体积上限。这些上限是应用决策。[forward/node 定义](https://napneko.github.io/develop/msg)、[配置源码](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/config/config.ts) |
| `get_forward_msg` | 接受 `id` 或 `message_id`，均为 string；至少一个必填。**NapCat 返回 `data.messages`（复数）**，为展开后的消息列表。 | 标准 OneBot 文档写 `data.message` 为 node 段数组；兼容层应区分两种形状。NapCat 数字 ID 路径依赖本地映射，内层或过期消息可能失败；资源 ID 路径有协议回退。[NapCat 实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/go-cqhttp/GetForwardMsg.ts)、[OneBot 标准](https://github.com/botuniverse/onebot-11/blob/master/api/public.md#get_forward_msg-获取合并转发消息) |
| `get_msg` | 参数 `message_id` 接受 number/string。返回 `time`, `message_type`, `message_id`, `real_id`, `message_seq`, `sender`, `message`, `raw_message`, `font`, `user_id`，可有 `group_id` 与 `emoji_likes_list`。 | 查询会因短 ID 映射丢失、撤回或超时失败。**当前实现把 `real_id` 和 `message_seq` 都重写成短 `message_id`，不能用它们推断 QQ 原生序号。**[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/msg/GetMsg.ts) |
| 成员角色 | `get_group_member_info` 参数 `group_id`, `user_id`，`no_cache` 可 boolean/string；返回 `role=owner/admin/member`、`card`、`nickname` 等。 | 明确传 `no_cache=true` 做敏感命令的角色复核；查询失败或未知 role 不授予管理权限。当前 NapCat 默认 no_cache=true，标准默认 false；不要依赖默认值。[查询实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/group/GetGroupMemberInfo.ts) |
| `get_group_info` | 参数 `group_id`。返回至少 `group_id`, `group_name`, `member_count`, `max_member_count`；常带 `group_all_shut`, `group_remark`。 | 当前源码没有读取标准的 `no_cache` 参数；不可把附带 no_cache=true 当成已强制刷新。可用于群存在性、群名称展示。[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/group/GetGroupInfo.ts) |
| 修改机器人群名片 | `set_group_card` 参数 `group_id`, `user_id=self_id`, `card`；空字符串清除名片。成功数据 null。 | 有 QQ 权限及服务端限制，必须检查响应；当前源码写入后最多三次刷新确认，每次间隔 1 秒，仍未生效则报错。[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/group/SetGroupCard.ts) |
| 群名片变更通知 | `notice_type=group_card`, `group_id`, `user_id`, `card_new`, `card_old`。 | `user_id` 指名片所属成员；事件没有标准 `operator_id`。检查 `user_id=self_id` 才是机器人名片变化。当前解析也会从消息携带的名片与缓存差异发现变化，不应当作覆盖所有修改的可靠审计流。[事件定义](https://napneko.github.io/onebot/event)、[解析源码](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/api/group.ts) |
| 群成员 / 管理 / 禁言通知 | `group_admin` 带 `sub_type=set/unset`; `group_increase` 带 approve/invite; `group_decrease` 带 leave/kick/kick_me/disband; `group_ban` 带 ban/lift_ban、`operator_id`, `duration`; 都带群和用户。 | 用于失效角色缓存、更新机器人所在群/可发送状态；仍需新查询确认关键权限。全群禁言可能以 `user_id=0` 表示。[事件定义](https://napneko.github.io/onebot/event) |
| 群消息撤回 | `notice_type=group_recall`, `group_id`, `user_id`, `operator_id`, `message_id`。 | 区分消息作者与撤回操作者；更新已存目标状态。撤回后不可指望 `get_msg` 恢复原文。[事件定义](https://napneko.github.io/onebot/event)、[资源时效说明](https://napneko.github.io/onebot/napcat) |
| 群公告 | 扩展 API 名为 **`_send_group_notice`** / **`_get_group_notice`**。发送需要 `group_id`, `content`，可选 image；配置字段 `pinned`, `type`, `confirm_required`, `is_show_edit_card`, `tip_window_type`。 | 发送取决于 QQ 权限，必须处理拒绝。获取返回数组，每项 `notice_id`, `sender_id`, `publish_time`, `message.text`, `message.image`/`images`，可有 settings/read_num；不是 `send_group_msg`，也不是普通 message.notice 事件。[发送](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/go-cqhttp/SendGroupNotice.ts)、[获取](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/group/GetGroupNotice.ts)、[API 路由名](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/router.ts) |
| 发送群消息 | `send_group_msg` 参数 `group_id`, `message`；字符串可带 `auto_escape`。成功 response `status=ok`, `retcode=0`, `data.message_id`。 | 使用段数组支持文字、引用、图片。NapCat 的 node 合并转发消息要求整个 message 数组只有 node，不能混入普通段；文字说明可放入 node 内容或另发一条。[发送实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/msg/SendMsg.ts)、[标准发送参数](https://github.com/botuniverse/onebot-11/blob/master/api/public.md#send_group_msg-发送群消息) |

## Reaction：可做每人投票，但必须按能力降级

### 当前线协议形状

这是 NapCat 扩展，不是 OneBot 11 标准通知。共同 envelope 为 `time:number`, `self_id:number`, `post_type=notice`；事件字段为：

| 字段 | 当前定义 / 含义 |
| --- | --- |
| `notice_type` | `group_msg_emoji_like` |
| `group_id` | number，目标群 |
| `user_id` | number，回应操作人；源码注明可能无法提供，不可假定永远存在且有效 |
| `message_id` | number，被回应的消息短 ID |
| `likes` | 数组；每项 `emoji_id:string`, `count:number` |
| `is_add` | boolean；true 添加，false 撤销 |
| `message_seq` | 类声明为 optional string，**构造函数没有赋值**；当前稳定版同样如此，不能依赖它出现在 JSON 中 |

依据：[稳定版事件类](https://github.com/NapNeko/NapCatQQ/blob/v4.18.19/packages/napcat-onebot/event/notice/OB11MsgEmojiLikeEvent.ts)、[当前解析器](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/api/group.ts)。当前 OneBot adapter 注册 core 的 `event:emoji_like`，core 提供 `groupId`, `senderUin`, `emojiId`, `msgSeq`, `isAdd`, `count`，然后转换为上述 OneBot 事件。[adapter 注册](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/index.ts)、[core 事件类型](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-core/packet/handler/eventList.ts)

### 已确认的版本 / 通路差异

| 范围 | 可靠结论 |
| --- | --- |
| 旧实现及仍公开的 V4 概览文档 | 事件形状没有 `is_add`；兼容表仍写仅接收对机器人自身消息的回应，其余使用扩展接口查询。[旧事件类](https://github.com/NapNeko/NapCatQQ/blob/2d46017d06b60901ede12dd0e6469c050c9074c2/src/onebot/event/notice/OB11MsgEmojiLikeEvent.ts)、[兼容表](https://napneko.github.io/develop/event) |
| 2025-11-01 上游提交 `516500f1` | 加入非自身消息回应解析，同时增加 `is_add`。原始 packet 通路将操作人 UID 转 QQ 号，type=1 转为添加，其余转为撤销；该通路把 count 固定为 1。[功能提交](https://github.com/NapNeko/NapCatQQ/commit/516500f1b2ec4d0f93eea86c72d16ec76230b3a5) |
| v4.18.19 与当前 main | 事件类均有 `is_add`，均未赋值 `message_seq`。当前还保留灰条 fallback：packet 可用时停用该 fallback，否则它只把机器人自身消息的灰条解析为 `is_add=true, count=1`。因此版本号本身不能证明所有目标、所有删除都能收到。[稳定版类](https://github.com/NapNeko/NapCatQQ/blob/v4.18.19/packages/napcat-onebot/event/notice/OB11MsgEmojiLikeEvent.ts)、[当前解析器](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/api/group.ts) |

本次确认了功能引入提交，未验证首个包含该提交的发布 tag；不要杜撰一个最低兼容版本号。部署应固定 NapCat 与 QQ 版本，并实际验证：他人的消息 / 机器人的消息，各自的添加与删除；两个用户；不同 emoji；短时间 add-remove-add；断线恢复。**没有这些实测，Reaction 只能算可选能力。**

v0.1 应按应用规则维护 `(bot, group, target_message, actor, emoji)` 的当前状态，重复 add/remove 幂等；不要把 `likes.count` 直接累加到投票总数。Actor 缺失/无效或 `is_add` 缺失的旧事件，不能安全地修改每人投票，记录后忽略或标记待核对。保留引用目标消息的显式文字投票命令作为可用降级。这些是基于上述源码限制的应用设计建议。

### 拉取回应者不能自动消除身份及删除风险

| API | 参数与响应 | 限制 |
| --- | --- | --- |
| `get_emoji_likes` | `message_id:string`, `emoji_id:string`, `emoji_type?:string`, `group_id?:string`, `count:number`（0 表示请求全部）。长 ID 必须传 group_id。返回 `emoji_like_list:[{user_id:string,nick_name:string}]`。 | 源码把上游 `tinyId` 直接放入 user_id，未显式转为 QQ UIN。部署实测前，不要假设它与消息 sender.user_id 同一命名空间；count=0 的循环仍有 200 页、每页 15 条上限，返回没有完整性标志。不能仅凭一次缺席就撤销投票。[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/extends/GetEmojiLikes.ts) |
| `fetch_emoji_like` | `message_id`, camelCase `emojiId`, `emojiType`, `count`, `cookie`。返回 `emojiLikesList:[{tinyId,nickName,headUrl}]`, `cookie`, `isLastPage`, `isFirstPage`, `result`, `errMsg`。 | 原始分页扩展；与上面的 snake_case API 不同。需要查完整分页、确认响应有效及身份映射。[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/extends/FetchEmojiLike.ts) |
| `set_msg_emoji_like` | `message_id`, `emoji_id`, `set`（可 boolean/string，默认 true；false 撤销）。 | 这是操作机器人自己的回应，不是修改其他成员回应。[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/msg/SetMsgEmojiLike.ts) |

## WebSocket、重连与事件身份

NapCat 正向 WebSocket 是 NapCat 监听、应用连接；反向 WebSocket 是 NapCat 主动连接应用。标准 `/api` 只提供 API，`/event` 提供事件，`/` 双向复用。请求 `{action, params, echo}` 与响应 `{status, retcode, data, echo}` 同连接返回，`echo` 只是请求关联标识。[OneBot WebSocket](https://github.com/botuniverse/onebot-11/blob/master/communication/ws.md)

当前反向客户端发送 `X-Self-ID`、`X-Client-Role: Universal`、`Authorization: Bearer <token>`；断开/错误后按 `reconnectInterval` 重连。NapCat 配置默认重连 5000 ms、`heartInterval=30000` ms、`messagePostFormat=array`、`reportSelfMessage=false`。正向服务端接受 Bearer 或 query `access_token`；应用宜用 Bearer 避免 URL 日志泄漏。[客户端源码](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/network/websocket-client.ts)、[服务端源码](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/network/websocket-server.ts)、[配置](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/config/config.ts)

`meta_event_type=lifecycle, sub_type=connect` 表示连接；heartbeat 含 `status.online`, `status.good`, `interval`。它们没有恢复游标。OneBot 11 envelope 没有全局 `event_id`，Reaction 也没有单次操作 ID。WebSocket 规范没有事件确认或可重放日志，当前客户端只在连接 OPEN 时发送，否则拒绝；**重连不等于已补齐离线事件**。[事件字段](https://napneko.github.io/onebot/event)、[规范](https://github.com/botuniverse/onebot-11/blob/master/communication/ws.md)、[实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/network/websocket-client.ts)

NapCat 短消息 ID 来自原生 msgId、chatType、peerUid 的截断 MD5，保持非负 int32；内存映射默认容量 5000，可调整。它不是数据库中永久可回查的原生 ID；哈希也存在碰撞可能。保存消息可用 `(self_id, group_id, message_id)` 作为首要匹配键，同时检查已有记录的发送者/时间/内容是否冲突。ID 在应用层统一为不做算术的字符串；time 是秒级时间，不是唯一事件键。不要永久 dedup 某个 actor/emoji 的 add 事件，否则合法 add-remove-add 会丢掉最后一次 add。[ID 源码](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-common/src/message-unique.ts)

## 发送不能承诺 exactly-once

`send_group_msg` 没有服务端幂等键；`echo` 只原样返回，不会阻止执行两次。NapCat 先执行 action、之后才发送响应；QQ 已收消息而响应在断线中丢失是可能的。重复调用相同 echo 不能证明不会重复发送。这是根据[发送实现](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/msg/SendMsg.ts)与[WebSocket 执行顺序](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/network/websocket-server.ts)得出的分布式故障结论。

建议 outbox 对业务投递意图设唯一约束并在发送前持久化发送状态；收到成功响应后保存目标 message_id。连接中断、请求超时、进程在发送后崩溃的条目进入 **unknown/待核对**，不自动重发；仅对确认尚未发出的条目自动重试。`message_sent` 或群历史可以辅助核对，但不是与原事务原子绑定的投递凭证。界面准确表述为防止重复排队和可核对投递，不声称 exactly-once。

## 另外两个应进入实现的边界

- **转发节点不是可信来源元数据。** 当前 `get_forward_msg` 资源回退构造了包含占位群号 `284840486`、占位发送号 `1094950020` 的内部消息；公开 issue 也报告了子节点 group_id 泄漏。仅用外层真实群事件做群授权、收集来源和消息归属；节点作者/群号仅展示，不能授权管理操作。[源码](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/action/go-cqhttp/GetForwardMsg.ts)、[上游问题 #1788](https://github.com/NapNeko/NapCatQQ/issues/1788)
- **展示性成员字段不能授予权限。** 当前转换器将 `card_changeable` 固定为 true；角色转换只有 NT role 4/3/2 对应 owner/admin/member，其他值可能 undefined。管理授权只认有效、及时的角色结果与应用管理员配置。[成员转换](https://github.com/NapNeko/NapCatQQ/blob/96de2314b0a82ad6156d92ff4b3921fd46f494c1/packages/napcat-onebot/helper/data.ts)
