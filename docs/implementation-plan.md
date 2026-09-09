# 搬💩 v0.1 Implementation Plan

Goal: 实现用户完整 v0.1 规格并交付可启动产品与完整源码历史。
Architecture: Rails 单体，规范化 PostgreSQL 模型、统一配置、内部事件、明确 Service 边界；SSR 公开档案馆。
Tech Stack: Ruby / Rails / PostgreSQL / GoodJob / ERB / Local or S3。
Spec: docs/architecture.md + 用户 60 节规格。

## Global constraints
- 不使用 AI；不分析消息文本语义。
- Safety 永远高于 Distribution；沉默不是负面；网站账号与 QQ 身份分离。
- 唯一模拟部分为真实 NapCat 连接。
- AppConfig 管理算法 ENV；数据库群偏好不能覆盖平台安全硬限制。
- 多 Bot，Group 历史独立；真实的 SHA256 与 pHash；公开页面不泄露 QQ 标识。

## Tasks
- [ ] 1. Foundation: Gemfile/config/environment, migrations, model relations, typed AppConfig. Verify boot/config/db constraints; commit.
- [ ] 2. Input/storage/duplicates: normalized event builder, adapters, local/S3, real DCT pHash and reversible merge. Contract tests for idempotency/out-of-order and hash distances; commit.
- [ ] 3. Collector/reputation: candidate observation, explanation ledger, natural occurrences and revival. Boundary/clock/cold-start tests; commit.
- [ ] 4. Safety/trial/distribution: safety audit, reports, seat rotation, unique feedback, rate reservations, timed evaluations and classic. Safety priority/unknown/retry/quota tests; commit.
- [ ] 5. Website/auth: public entry/group/transporter/ranking/search routes, login/register/profile/favorites/ratings/reports, claim and scoped management. Request/authorization/privacy tests; commit.
- [ ] 6. Fake QQ + seeds: persistent virtual members/messages/cards, stepwise simulation through actual EventProcessor, rich original safe fixtures. End-to-end lifecycle tests; commit.
- [ ] 7. Operations/docs: recurring jobs, structured logging, Docker and boot scripts, complete ENV/reference/README, integration validation, packaging with Git history; commit.

Testing commands: bundle exec rails test; bundle exec rails zeitwerk:check; bundle exec rails db:prepare; bin/demo; HTTP route/request suite. Browser/render check where runtime supports it. Do not claim a check passed if it did not execute.
