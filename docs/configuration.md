# 统一配置参考

配置优先级：代码默认值 → ENV → 群数据库偏好。群偏好只覆盖胃口、摄入量、冷却等群设置，不能突破 RED 或平台硬标签。

`config/app_config.rb` 集中处理类型、默认值和启动校验。时间单位转换为秒，业务使用 `AppConfig.section.key`。更换来源时修改 `AppConfig.load(source)`。

此文件和 `.env.example` 由 `ruby script/config_reference.rb` 生成，新增配置后请重新运行。

## system

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `RAILS_ENV` | `system.environment` | string | development |
| `PORT` | `system.port` | integer | 3000 |
| `RAILS_MAX_THREADS` | `system.web_threads` | integer | 5 |
| `SECRET_KEY_BASE` | `system.secret_key_base` | string | 开发专用占位密钥；生产必须替换 |
| `ALLOWED_HOSTS` | `system.allowed_hosts` | list | [] |
| `FORCE_SSL` | `system.force_ssl` | boolean | false |
| `PAGE_SIZE` | `system.page_size` | integer | 18 |
| `TIME_ZONE` | `system.time_zone` | string | Asia/Shanghai |

## database

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `DATABASE_URL` | `database.url` | string | postgresql://localhost/banshi_development |
| `TEST_DATABASE_URL` | `database.test_url` | string | postgresql://localhost/banshi_test |
| `DATABASE_POOL` | `database.pool` | integer | 12 |
| `DATABASE_PREPARED_STATEMENTS` | `database.prepared_statements` | boolean | true |
| `TEST_MAINTAIN_SCHEMA` | `database.maintain_test_schema` | boolean | true |

## candidate

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `CANDIDATE_TTL_MINUTES` | `candidate.ttl` | minutes | 5 |
| `CANDIDATE_REPLY_WEIGHT` | `candidate.reply_weight` | float | 2 |
| `CANDIDATE_QUOTE_WEIGHT` | `candidate.quote_weight` | float | 2.5 |
| `CANDIDATE_REACTION_WEIGHT` | `candidate.reaction_weight` | float | 1.5 |
| `CANDIDATE_REPEAT_WEIGHT` | `candidate.repeat_weight` | float | 5 |
| `CANDIDATE_FORWARD_BASE_SCORE` | `candidate.forward_base` | float | 1 |
| `CANDIDATE_IMAGE_BASE_SCORE` | `candidate.image_base` | float | 0 |
| `CANDIDATE_MIN_SCORE` | `candidate.min_score` | float | 1.5 |
| `CANDIDATE_MIN_UNIQUE_USERS` | `candidate.min_unique_users` | integer | 1 |
| `CANDIDATE_ACTIVITY_WEIGHT` | `candidate.activity_weight` | float | 0 |
| `CANDIDATE_MAX_LATE_MINUTES` | `candidate.max_late_age` | minutes | 1440 |

## reputation

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `REPUTATION_ENABLED` | `reputation.enabled` | boolean | true |
| `REPUTATION_MIN_SAMPLES` | `reputation.min_samples` | integer | 5 |
| `REPUTATION_PRIOR_SUCCESSES` | `reputation.prior_successes` | float | 3 |
| `REPUTATION_PRIOR_FAILURES` | `reputation.prior_failures` | float | 3 |
| `REPUTATION_MAX_ADJUSTMENT` | `reputation.max_adjustment` | float | 1 |
| `REPUTATION_NATURAL_WEIGHT` | `reputation.natural_weight` | float | 0.3 |
| `REPUTATION_CLASSIC_WEIGHT` | `reputation.classic_weight` | float | 1 |

## duplicate

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `DUPLICATE_PHASH_THRESHOLD` | `duplicate.phash_threshold` | integer | 5 |
| `DUPLICATE_POSSIBLE_THRESHOLD` | `duplicate.possible_threshold` | integer | 12 |
| `DUPLICATE_ASPECT_TOLERANCE` | `duplicate.aspect_tolerance` | float | 0.12 |
| `DUPLICATE_SCAN_LIMIT` | `duplicate.scan_limit` | integer | 2000 |

## safety

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `SAFETY_DEFAULT_LEVEL` | `safety.default_level` | string | GREEN |
| `SAFETY_DEFAULT_VISIBILITY` | `safety.default_visibility` | string | public |
| `SAFETY_TAGS` | `safety.tags` | list | ["GORE","NSFW","GROTESQUE","HARASSMENT","PRIVACY","EXTREME","OTHER_SENSITIVE"] |
| `SAFETY_HARD_BLOCK_TAGS` | `safety.hard_block_tags` | list | ["PRIVACY","EXTREME"] |
| `SAFETY_FILE_BLACKLIST` | `safety.file_blacklist` | list | [] |
| `SAFETY_SOURCE_BLACKLIST` | `safety.source_blacklist` | list | [] |
| `REPORT_AUTO_PAUSE_THRESHOLD` | `safety.report_pause_threshold` | integer | 3 |
| `REPORT_URGENT_REASONS` | `safety.urgent_report_reasons` | list | ["privacy","minors"] |

## trial

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `TRIAL_ENABLED` | `trial.enabled` | boolean | true |
| `TRIAL_GROUP_MIN` | `trial.group_min` | integer | 3 |
| `TRIAL_GROUP_MAX` | `trial.group_max` | integer | 5 |
| `TRIAL_DURATION_MINUTES` | `trial.duration` | minutes | 60 |
| `TRIAL_REACTION_GOOD` | `trial.reaction_good` | string | 💩 |
| `TRIAL_REACTION_FUNNY` | `trial.reaction_funny` | string | 😂 |
| `TRIAL_REACTION_BAD` | `trial.reaction_bad` | string | 🥱 |
| `TRIAL_MIN_RESPONSIVE_GROUPS` | `trial.min_responsive_groups` | integer | 1 |
| `TRIAL_POSITIVE_THRESHOLD` | `trial.positive_threshold` | float | 0.5 |
| `TRIAL_NEGATIVE_MAX` | `trial.negative_max` | float | 0.4 |
| `TRIAL_REPLY_POSITIVE_MIN` | `trial.reply_positive_min` | integer | 2 |
| `TRIAL_GOOD_WEIGHT` | `trial.good_weight` | float | 2 |
| `TRIAL_FUNNY_WEIGHT` | `trial.funny_weight` | float | 1 |
| `TRIAL_BAD_WEIGHT` | `trial.bad_weight` | float | 2 |
| `TRIAL_MAX_WAIT_HOURS` | `trial.max_wait` | hours | 24 |
| `TRIAL_REQUIRED_BEFORE_DISTRIBUTION` | `trial.required_before_distribution` | boolean | false |

## distribution

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `DISTRIBUTION_ENABLED` | `distribution.enabled` | boolean | true |
| `DISTRIBUTION_GROUP_DAILY_LIMIT` | `distribution.daily_limit` | integer | 6 |
| `DISTRIBUTION_GROUP_COOLDOWN_MINUTES` | `distribution.cooldown` | minutes | 60 |
| `DISTRIBUTION_GLOBAL_PER_MINUTE` | `distribution.global_per_minute` | integer | 20 |
| `DISTRIBUTION_BATCH_SIZE` | `distribution.batch_size` | integer | 3 |
| `DISTRIBUTION_REPEAT_AFTER_DAYS` | `distribution.repeat_after` | days | 90 |
| `HOT_SCORE_THRESHOLD` | `distribution.hot_score_threshold` | float | 18 |
| `HOT_MIN_NATURAL_OCCURRENCES` | `distribution.hot_min_natural` | integer | 5 |
| `HOT_WINDOW_DAYS` | `distribution.hot_window` | days | 7 |
| `DISTRIBUTION_NEXT_ROUND_MINUTES` | `distribution.next_round` | minutes | 15 |
| `DISTRIBUTION_MIN_FEEDBACK` | `distribution.min_feedback` | integer | 1 |

## classic

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `CLASSIC_MIN_NATURAL_OCCURRENCES` | `classic.min_natural_occurrences` | integer | 8 |
| `CLASSIC_MIN_NATURAL_GROUPS` | `classic.min_groups` | integer | 3 |
| `CLASSIC_MIN_LIFESPAN_DAYS` | `classic.min_lifespan` | days | 90 |
| `CLASSIC_MIN_REVIVALS` | `classic.min_revivals` | integer | 1 |
| `REVIVAL_GAP_DAYS` | `classic.revival_gap` | days | 30 |

## claim

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `CLAIM_TTL_MINUTES` | `claim.ttl` | minutes | 10 |
| `CLAIM_MAX_ATTEMPTS` | `claim.max_attempts` | integer | 6 |
| `CLAIM_TOKEN_LENGTH` | `claim.token_length` | integer | 8 |

## leaderboard

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `LEADERBOARD_PERIOD_DAYS` | `leaderboard.period` | days | 7 |
| `LEADERBOARD_LIMIT` | `leaderboard.limit` | integer | 20 |

## napcat

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `NAPCAT_ENABLED` | `napcat.enabled` | boolean | false |
| `NAPCAT_WS_URL` | `napcat.ws_url` | string | ws://127.0.0.1:3001 |
| `NAPCAT_HTTP_URL` | `napcat.http_url` | string | http://127.0.0.1:3001 |
| `NAPCAT_ACCESS_TOKEN` | `napcat.access_token` | string | 空 |
| `NAPCAT_WEBHOOK_TOKEN` | `napcat.webhook_token` | string | 空 |
| `NAPCAT_REQUEST_TIMEOUT_SECONDS` | `napcat.request_timeout` | integer | 10 |
| `NAPCAT_REACTION_MAP` | `napcat.reaction_map` | json | {"128169":"💩","128514":"😂","129393":"🥱"} |
| `NAPCAT_MEDIA_ALLOWED_HOSTS` | `napcat.media_allowed_hosts` | list | ["multimedia.nt.qq.com","gchat.qpic.cn","c2cpicdw.qpic.cn"] |
| `NAPCAT_MAX_MEDIA_BYTES` | `napcat.max_media_bytes` | integer | 20000000 |
| `RAW_EVENT_RETENTION_DAYS` | `napcat.event_retention` | days | 14 |
| `NAPCAT_RECONNECT_SECONDS` | `napcat.reconnect_delay` | integer | 5 |
| `NAPCAT_MAX_FORWARD_DEPTH` | `napcat.max_forward_depth` | integer | 5 |
| `NAPCAT_MAX_FORWARD_NODES` | `napcat.max_forward_nodes` | integer | 200 |
| `NAPCAT_MAX_FORWARD_MEDIA` | `napcat.max_forward_media` | integer | 50 |
| `NAPCAT_MAX_MEDIA_PIXELS` | `napcat.max_media_pixels` | integer | 40000000 |
| `NAPCAT_CONNECTION_TOKENS` | `napcat.connection_tokens` | json | {} |
| `NAPCAT_CONNECTIONS` | `napcat.connections` | json | {} |
| `NAPCAT_SYNC_SECONDS` | `napcat.sync_interval` | integer | 60 |

## storage

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `STORAGE_PROVIDER` | `storage.provider` | string | local |
| `STORAGE_LOCAL_ROOT` | `storage.local_root` | string | storage/media |
| `STORAGE_ENDPOINT` | `storage.endpoint` | string | 空 |
| `STORAGE_BUCKET` | `storage.bucket` | string | 空 |
| `STORAGE_ACCESS_KEY` | `storage.access_key` | string | 空 |
| `STORAGE_SECRET_KEY` | `storage.secret_key` | string | 空 |
| `STORAGE_REGION` | `storage.region` | string | us-east-1 |

## features

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `FEATURE_TRIAL` | `features.trial` | boolean | true |
| `FEATURE_REPUTATION` | `features.reputation` | boolean | true |
| `FEATURE_PHASH` | `features.phash` | boolean | true |
| `FEATURE_PUBLIC_GROUPS` | `features.public_groups` | boolean | true |
| `FEATURE_WEB_RATING` | `features.web_rating` | boolean | true |
| `FEATURE_AUTO_CLASSIC` | `features.auto_classic` | boolean | true |
| `FEATURE_GROUP_TASTE_PROFILE` | `features.group_taste_profile` | boolean | true |

## demo

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `DEMO_ENABLED` | `demo.enabled` | boolean | true |
| `SEED_DEMO` | `demo.seed` | boolean | true |
| `DEMO_EMAIL` | `demo.email` | string | curator@example.test |
| `DEMO_PASSWORD` | `demo.password` | string | Museum-demo-2026! |

## jobs

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `JOB_THREADS` | `jobs.threads` | integer | 5 |
| `JOB_POLL_INTERVAL` | `jobs.poll_interval` | integer | 5 |
| `JOB_CRON_ENABLED` | `jobs.cron_enabled` | boolean | true |
| `JOB_MAINTENANCE_CRON` | `jobs.maintenance_cron` | string | * * * * * |
| `JOB_STATISTICS_CRON` | `jobs.statistics_cron` | string | */15 * * * * |
| `JOB_RETRY_ATTEMPTS` | `jobs.attempts` | integer | 5 |

## security

| ENV | AppConfig | 类型 / 输入单位 | 默认值 |
| --- | --- | --- | --- |
| `LOGIN_RATE_LIMIT` | `security.login_limit` | integer | 10 |
| `SIGNUP_RATE_LIMIT` | `security.signup_limit` | integer | 5 |
| `CLAIM_RATE_LIMIT` | `security.claim_limit` | integer | 10 |
| `AUTH_RATE_PERIOD_SECONDS` | `security.rate_period` | integer | 60 |
| `SIGNUP_RATE_PERIOD_SECONDS` | `security.signup_period` | integer | 300 |

