# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_09_050000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "assets", force: :cascade do |t|
    t.string "sha256", null: false
    t.string "phash"
    t.string "storage_key", null: false
    t.string "content_type", null: false
    t.integer "width"
    t.integer "height"
    t.bigint "byte_size", null: false
    t.string "visibility", default: "visible", null: false
    t.bigint "original_asset_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["original_asset_id"], name: "index_assets_on_original_asset_id"
    t.index ["phash"], name: "idx_assets_2"
    t.index ["sha256"], name: "idx_assets_0", unique: true
    t.index ["storage_key"], name: "idx_assets_1", unique: true
  end

  create_table "attachments", force: :cascade do |t|
    t.bigint "content_id", null: false
    t.bigint "asset_id", null: false
    t.integer "position", default: 0, null: false
    t.string "role", default: "original", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_attachments_on_asset_id"
    t.index ["content_id", "position"], name: "idx_attachments_0", unique: true
    t.index ["content_id"], name: "index_attachments_on_content_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "group_id"
    t.bigint "shit_entry_id"
    t.string "category", null: false
    t.string "action", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "created_at"], name: "idx_audit_logs_0"
    t.index ["group_id"], name: "index_audit_logs_on_group_id"
    t.index ["shit_entry_id"], name: "index_audit_logs_on_shit_entry_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "bot_accounts", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "idx_bot_accounts_0", unique: true
  end

  create_table "bot_connections", force: :cascade do |t|
    t.bigint "bot_account_id", null: false
    t.string "name", null: false
    t.string "adapter", default: "fake", null: false
    t.string "status", default: "online", null: false
    t.string "endpoint"
    t.string "credential_env_key"
    t.datetime "last_seen_at"
    t.jsonb "capabilities", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_account_id"], name: "index_bot_connections_on_bot_account_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "group_id", null: false
    t.bigint "transporter_id"
    t.bigint "content_id", null: false
    t.bigint "shit_entry_id"
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "evaluated_at"
    t.float "score", default: 0.0, null: false
    t.float "reputation_snapshot", default: 0.5, null: false
    t.string "decision_reason"
    t.jsonb "rule_results", default: {}, null: false
    t.string "duplicate_status"
    t.float "duplicate_confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_candidates_on_content_id"
    t.index ["group_id"], name: "index_candidates_on_group_id"
    t.index ["message_id"], name: "index_candidates_on_message_id"
    t.index ["message_id"], name: "unique_candidate_message", unique: true
    t.index ["shit_entry_id"], name: "index_candidates_on_shit_entry_id"
    t.index ["status", "expires_at"], name: "idx_candidates_0"
    t.index ["transporter_id"], name: "index_candidates_on_transporter_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'accepted'::character varying::text, 'expired'::character varying::text, 'rejected'::character varying::text, 'duplicate'::character varying::text, 'unsafe'::character varying::text])", name: "candidates_valid_status"
  end

  create_table "claim_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id"
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at", "used_at"], name: "idx_claim_tokens_1"
    t.index ["group_id"], name: "index_claim_tokens_on_group_id"
    t.index ["token_digest"], name: "idx_claim_tokens_0", unique: true
    t.index ["user_id"], name: "index_claim_tokens_on_user_id"
  end

  create_table "contents", force: :cascade do |t|
    t.string "kind", null: false
    t.string "fingerprint", null: false
    t.text "text_body"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "idx_contents_0"
  end

  create_table "deliveries", force: :cascade do |t|
    t.bigint "shit_entry_id", null: false
    t.bigint "group_id", null: false
    t.bigint "bot_connection_id", null: false
    t.bigint "trial_run_id"
    t.bigint "message_id"
    t.string "kind", null: false
    t.string "status", default: "pending", null: false
    t.string "idempotency_key", null: false
    t.string "external_message_id"
    t.datetime "sent_at"
    t.text "error_message"
    t.jsonb "decision", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_connection_id"], name: "index_deliveries_on_bot_connection_id"
    t.index ["group_id", "created_at"], name: "idx_deliveries_1"
    t.index ["group_id"], name: "index_deliveries_on_group_id"
    t.index ["idempotency_key"], name: "idx_deliveries_0", unique: true
    t.index ["message_id"], name: "index_deliveries_on_message_id"
    t.index ["shit_entry_id", "group_id"], name: "idx_deliveries_2"
    t.index ["shit_entry_id"], name: "index_deliveries_on_shit_entry_id"
    t.index ["trial_run_id"], name: "index_deliveries_on_trial_run_id"
  end

  create_table "duplicate_matches", force: :cascade do |t|
    t.bigint "content_id", null: false
    t.bigint "shit_entry_id", null: false
    t.string "method", null: false
    t.string "status", default: "possible", null: false
    t.float "confidence", null: false
    t.integer "distance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id", "shit_entry_id"], name: "idx_duplicate_matches_0", unique: true
    t.index ["content_id"], name: "index_duplicate_matches_on_content_id"
    t.index ["shit_entry_id"], name: "index_duplicate_matches_on_shit_entry_id"
  end

  create_table "entry_merges", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "target_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.text "reason", null: false
    t.datetime "reverted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_entry_merges_on_source_id"
    t.index ["target_id"], name: "index_entry_merges_on_target_id"
    t.index ["user_id"], name: "index_entry_merges_on_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "shit_entry_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shit_entry_id"], name: "index_favorites_on_shit_entry_id"
    t.index ["user_id", "shit_entry_id"], name: "idx_favorites_0", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "forward_nodes", force: :cascade do |t|
    t.bigint "content_id", null: false
    t.bigint "parent_id"
    t.integer "position", null: false
    t.string "display_name", default: "匿名群友", null: false
    t.text "body"
    t.datetime "sent_at"
    t.bigint "asset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_forward_nodes_on_asset_id"
    t.index ["content_id", "position"], name: "idx_forward_nodes_0", unique: true
    t.index ["content_id"], name: "index_forward_nodes_on_content_id"
    t.index ["parent_id"], name: "index_forward_nodes_on_parent_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "group_bot_memberships", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "bot_account_id", null: false
    t.string "card", default: "自助餐", null: false
    t.boolean "active", default: true, null: false
    t.datetime "joined_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "membership_event_at"
    t.bigint "membership_event_id"
    t.datetime "card_event_at"
    t.bigint "card_event_id"
    t.index ["bot_account_id"], name: "index_group_bot_memberships_on_bot_account_id"
    t.index ["group_id", "bot_account_id"], name: "idx_group_bot_memberships_0", unique: true
    t.index ["group_id"], name: "index_group_bot_memberships_on_group_id"
  end

  create_table "group_managements", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "user_id", null: false
    t.string "verified_role", null: false
    t.datetime "verified_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "user_id"], name: "idx_group_managements_0", unique: true
    t.index ["group_id"], name: "index_group_managements_on_group_id"
    t.index ["user_id"], name: "index_group_managements_on_user_id"
  end

  create_table "group_members", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "transporter_id", null: false
    t.string "role", default: "member", null: false
    t.string "display_name"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "membership_event_at"
    t.bigint "membership_event_id"
    t.datetime "role_event_at"
    t.bigint "role_event_id"
    t.index ["group_id", "transporter_id"], name: "idx_group_members_0", unique: true
    t.index ["group_id"], name: "index_group_members_on_group_id"
    t.index ["transporter_id"], name: "index_group_members_on_transporter_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "slug", null: false
    t.string "public_name", null: false
    t.string "anonymous_name", null: false
    t.text "description"
    t.string "visibility", default: "statistics", null: false
    t.boolean "anonymous", default: true, null: false
    t.boolean "hide_members", default: true, null: false
    t.string "mode", default: "自助餐", null: false
    t.boolean "collect_enabled"
    t.boolean "distribute_enabled"
    t.string "trial_preference", default: "FALLBACK", null: false
    t.integer "daily_limit"
    t.integer "cooldown_minutes"
    t.string "accepted_tags", default: [], null: false, array: true
    t.boolean "accept_hot", default: true, null: false
    t.boolean "accept_classic", default: true, null: false
    t.boolean "accept_archaeology", default: false, null: false
    t.datetime "joined_at", null: false
    t.datetime "last_delivery_at"
    t.datetime "last_trial_at"
    t.jsonb "stats", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "mode_event_at"
    t.bigint "mode_event_id"
    t.index ["external_id"], name: "idx_groups_0", unique: true
    t.index ["slug"], name: "idx_groups_1", unique: true
    t.index ["trial_preference", "last_trial_at"], name: "idx_groups_3"
    t.index ["visibility", "joined_at"], name: "idx_groups_2"
    t.check_constraint "trial_preference::text = ANY (ARRAY['OPT_IN'::character varying::text, 'FALLBACK'::character varying::text, 'OPT_OUT'::character varying::text])", name: "groups_valid_trial_preference"
  end

  create_table "interactions", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "transporter_id", null: false
    t.bigint "message_id"
    t.bigint "internal_event_id"
    t.string "target_external_id", null: false
    t.string "kind", null: false
    t.string "reaction", default: "", null: false
    t.string "identity_key", null: false
    t.boolean "active", default: true, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "target_external_id", "active"], name: "idx_interactions_1"
    t.index ["group_id"], name: "index_interactions_on_group_id"
    t.index ["identity_key"], name: "idx_interactions_0", unique: true
    t.index ["internal_event_id"], name: "index_interactions_on_internal_event_id"
    t.index ["message_id"], name: "index_interactions_on_message_id"
    t.index ["transporter_id"], name: "index_interactions_on_transporter_id"
  end

  create_table "internal_events", force: :cascade do |t|
    t.bigint "raw_event_id"
    t.bigint "bot_connection_id"
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.string "group_external_id"
    t.string "sender_external_id"
    t.string "message_external_id"
    t.string "reply_to_message_id"
    t.string "content_type"
    t.datetime "occurred_at", null: false
    t.jsonb "media_references", default: [], null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_connection_id"], name: "index_internal_events_on_bot_connection_id"
    t.index ["event_id"], name: "idx_internal_events_0", unique: true
    t.index ["group_external_id", "message_external_id"], name: "idx_internal_events_2"
    t.index ["raw_event_id"], name: "index_internal_events_on_raw_event_id"
    t.index ["status", "occurred_at"], name: "idx_internal_events_1"
  end

  create_table "leaderboard_snapshots", force: :cascade do |t|
    t.string "board", null: false
    t.datetime "generated_at", null: false
    t.jsonb "rows", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board"], name: "idx_leaderboard_snapshots_0", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "transporter_id"
    t.bigint "bot_account_id"
    t.bigint "internal_event_id"
    t.bigint "content_id"
    t.string "external_id", null: false
    t.string "reply_to_external_id"
    t.string "source", default: "NATURAL", null: false
    t.string "kind", default: "text", null: false
    t.text "body"
    t.datetime "sent_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_account_id"], name: "index_messages_on_bot_account_id"
    t.index ["content_id"], name: "index_messages_on_content_id"
    t.index ["group_id", "external_id"], name: "idx_messages_0", unique: true
    t.index ["group_id", "sent_at"], name: "idx_messages_1"
    t.index ["group_id"], name: "index_messages_on_group_id"
    t.index ["internal_event_id"], name: "index_messages_on_internal_event_id"
    t.index ["transporter_id"], name: "index_messages_on_transporter_id"
  end

  create_table "raw_events", force: :cascade do |t|
    t.bigint "bot_connection_id", null: false
    t.string "digest", null: false
    t.jsonb "payload", null: false
    t.datetime "received_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_connection_id", "digest"], name: "idx_raw_events_0", unique: true
    t.index ["bot_connection_id"], name: "index_raw_events_on_bot_connection_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "shit_entry_id", null: false
    t.bigint "user_id", null: false
    t.bigint "reviewer_id"
    t.string "reason", null: false
    t.text "details"
    t.string "status", default: "open", null: false
    t.text "resolution"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewer_id"], name: "index_reports_on_reviewer_id"
    t.index ["shit_entry_id", "user_id"], name: "one_open_report_per_user_entry", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["shit_entry_id"], name: "index_reports_on_shit_entry_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "safety_decisions", force: :cascade do |t|
    t.bigint "shit_entry_id", null: false
    t.bigint "user_id"
    t.string "level", null: false
    t.string "tags", default: [], null: false, array: true
    t.string "source", null: false
    t.string "rule"
    t.text "reason", null: false
    t.string "visibility", null: false
    t.datetime "decided_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shit_entry_id"], name: "index_safety_decisions_on_shit_entry_id"
    t.index ["user_id"], name: "index_safety_decisions_on_user_id"
  end

  create_table "shit_entries", force: :cascade do |t|
    t.bigint "content_id", null: false
    t.bigint "first_group_id", null: false
    t.bigint "first_transporter_id"
    t.string "sid", null: false
    t.string "title"
    t.text "summary"
    t.string "level", default: "ARCHIVED", null: false
    t.string "safety_level", default: "RED", null: false
    t.string "safety_tags", default: [], null: false, array: true
    t.string "visibility", default: "hidden", null: false
    t.boolean "distribution_paused", default: false, null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_natural_at", null: false
    t.datetime "first_distributed_at"
    t.datetime "classic_at"
    t.integer "natural_count", default: 0, null: false
    t.integer "bot_count", default: 0, null: false
    t.integer "natural_group_count", default: 0, null: false
    t.integer "interaction_count", default: 0, null: false
    t.integer "revival_count", default: 0, null: false
    t.float "distribution_score", default: 0.0, null: false
    t.bigint "merged_into_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_shit_entries_on_content_id"
    t.index ["first_group_id"], name: "index_shit_entries_on_first_group_id"
    t.index ["first_transporter_id"], name: "index_shit_entries_on_first_transporter_id"
    t.index ["merged_into_id"], name: "index_shit_entries_on_merged_into_id"
    t.index ["natural_count", "last_natural_at"], name: "idx_shit_entries_2"
    t.index ["safety_tags"], name: "index_shit_entries_on_safety_tags", using: :gin
    t.index ["sid"], name: "idx_shit_entries_0", unique: true
    t.index ["title"], name: "index_shit_entries_on_title", opclass: :gin_trgm_ops, using: :gin
    t.index ["visibility", "level", "first_seen_at"], name: "idx_shit_entries_1"
    t.check_constraint "level::text = ANY (ARRAY['ARCHIVED'::character varying::text, 'TRIAL'::character varying::text, 'NORMAL'::character varying::text, 'HOT'::character varying::text, 'CLASSIC'::character varying::text])", name: "shit_entries_valid_level"
  end

  create_table "shit_occurrences", force: :cascade do |t|
    t.bigint "shit_entry_id", null: false
    t.bigint "group_id", null: false
    t.bigint "transporter_id"
    t.bigint "message_id", null: false
    t.bigint "delivery_id"
    t.bigint "trial_run_id"
    t.string "source", null: false
    t.datetime "occurred_at", null: false
    t.boolean "first_appearance", default: false, null: false
    t.boolean "duplicate_matched", default: false, null: false
    t.float "match_confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_shit_occurrences_on_delivery_id"
    t.index ["group_id", "source", "occurred_at"], name: "idx_shit_occurrences_1"
    t.index ["group_id"], name: "index_shit_occurrences_on_group_id"
    t.index ["message_id"], name: "index_shit_occurrences_on_message_id"
    t.index ["message_id"], name: "unique_occurrence_message", unique: true
    t.index ["shit_entry_id", "source", "occurred_at"], name: "idx_shit_occurrences_0"
    t.index ["shit_entry_id"], name: "index_shit_occurrences_on_shit_entry_id"
    t.index ["transporter_id"], name: "index_shit_occurrences_on_transporter_id"
    t.index ["trial_run_id"], name: "index_shit_occurrences_on_trial_run_id"
    t.check_constraint "source::text = ANY (ARRAY['NATURAL'::character varying::text, 'BOT_TRIAL'::character varying::text, 'BOT_DISTRIBUTION'::character varying::text, 'BOT_CLASSIC'::character varying::text])", name: "shit_occurrences_valid_source"
  end

  create_table "simulation_actions", force: :cascade do |t|
    t.bigint "simulation_run_id", null: false
    t.string "action_name", null: false
    t.jsonb "parameters", default: {}, null: false
    t.string "status", default: "queued", null: false
    t.text "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["simulation_run_id"], name: "index_simulation_actions_on_simulation_run_id"
    t.index ["status", "created_at"], name: "index_simulation_actions_on_status_and_created_at"
  end

  create_table "simulation_runs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "clock_at", null: false
    t.jsonb "state", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_simulation_runs_on_user_id", unique: true
  end

  create_table "system_errors", force: :cascade do |t|
    t.string "context", null: false
    t.string "error_class", null: false
    t.text "message"
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "timeline_events", force: :cascade do |t|
    t.bigint "shit_entry_id"
    t.bigint "group_id"
    t.bigint "transporter_id"
    t.string "event_type", null: false
    t.string "label", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "details", default: {}, null: false
    t.string "dedupe_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dedupe_key"], name: "idx_timeline_events_1", unique: true
    t.index ["group_id"], name: "index_timeline_events_on_group_id"
    t.index ["shit_entry_id", "occurred_at"], name: "idx_timeline_events_0"
    t.index ["shit_entry_id"], name: "index_timeline_events_on_shit_entry_id"
    t.index ["transporter_id"], name: "index_timeline_events_on_transporter_id"
  end

  create_table "transporters", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "public_id", null: false
    t.string "display_name", null: false
    t.boolean "public_profile", default: false, null: false
    t.integer "candidate_count", default: 0, null: false
    t.integer "accepted_count", default: 0, null: false
    t.integer "natural_count", default: 0, null: false
    t.integer "classic_count", default: 0, null: false
    t.float "reputation_score", default: 0.5, null: false
    t.jsonb "reputation_details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "idx_transporters_0", unique: true
    t.index ["public_id"], name: "idx_transporters_1", unique: true
  end

  create_table "trial_deliveries", force: :cascade do |t|
    t.bigint "trial_run_id", null: false
    t.bigint "group_id", null: false
    t.bigint "delivery_id", null: false
    t.string "feedback_state", default: "unknown", null: false
    t.jsonb "stats", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_trial_deliveries_on_delivery_id"
    t.index ["group_id"], name: "index_trial_deliveries_on_group_id"
    t.index ["trial_run_id", "group_id"], name: "idx_trial_deliveries_0", unique: true
    t.index ["trial_run_id"], name: "index_trial_deliveries_on_trial_run_id"
  end

  create_table "trial_results", force: :cascade do |t|
    t.bigint "trial_run_id", null: false
    t.integer "trial_group_count", default: 0, null: false
    t.integer "responsive_group_count", default: 0, null: false
    t.integer "good_reactions", default: 0, null: false
    t.integer "funny_reactions", default: 0, null: false
    t.integer "bad_reactions", default: 0, null: false
    t.integer "unique_reply_users", default: 0, null: false
    t.integer "unique_interaction_users", default: 0, null: false
    t.float "positive_rate", default: 0.0, null: false
    t.float "negative_rate", default: 0.0, null: false
    t.float "responsive_group_rate", default: 0.0, null: false
    t.float "distribution_score", default: 0.0, null: false
    t.string "verdict", null: false
    t.jsonb "explanation", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trial_run_id"], name: "index_trial_results_on_trial_run_id"
    t.index ["trial_run_id"], name: "unique_trial_result", unique: true
  end

  create_table "trial_runs", force: :cascade do |t|
    t.bigint "shit_entry_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "ends_at"
    t.datetime "finished_at"
    t.string "strategy", default: "rotating_opt_in", null: false
    t.jsonb "explanation", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shit_entry_id"], name: "index_trial_runs_on_shit_entry_id"
    t.index ["shit_entry_id"], name: "one_active_trial_per_entry", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('running'::character varying)::text]))"
    t.index ["status", "ends_at"], name: "idx_trial_runs_0"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "display_name", null: false
    t.string "site_role", default: "member", null: false
    t.string "public_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["public_id"], name: "idx_users_0", unique: true
  end

  create_table "web_ratings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "shit_entry_id", null: false
    t.string "reaction", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shit_entry_id"], name: "index_web_ratings_on_shit_entry_id"
    t.index ["user_id", "shit_entry_id", "reaction"], name: "idx_web_ratings_0", unique: true
    t.index ["user_id"], name: "index_web_ratings_on_user_id"
  end

  add_foreign_key "assets", "assets", column: "original_asset_id"
  add_foreign_key "attachments", "assets"
  add_foreign_key "attachments", "contents"
  add_foreign_key "audit_logs", "groups"
  add_foreign_key "audit_logs", "shit_entries"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "bot_connections", "bot_accounts"
  add_foreign_key "candidates", "contents"
  add_foreign_key "candidates", "groups"
  add_foreign_key "candidates", "messages"
  add_foreign_key "candidates", "shit_entries"
  add_foreign_key "candidates", "transporters"
  add_foreign_key "claim_tokens", "groups"
  add_foreign_key "claim_tokens", "users"
  add_foreign_key "deliveries", "bot_connections"
  add_foreign_key "deliveries", "groups"
  add_foreign_key "deliveries", "messages"
  add_foreign_key "deliveries", "shit_entries"
  add_foreign_key "deliveries", "trial_runs"
  add_foreign_key "duplicate_matches", "contents"
  add_foreign_key "duplicate_matches", "shit_entries"
  add_foreign_key "entry_merges", "shit_entries", column: "source_id"
  add_foreign_key "entry_merges", "shit_entries", column: "target_id"
  add_foreign_key "entry_merges", "users"
  add_foreign_key "favorites", "shit_entries"
  add_foreign_key "favorites", "users"
  add_foreign_key "forward_nodes", "assets"
  add_foreign_key "forward_nodes", "contents"
  add_foreign_key "forward_nodes", "forward_nodes", column: "parent_id"
  add_foreign_key "group_bot_memberships", "bot_accounts"
  add_foreign_key "group_bot_memberships", "groups"
  add_foreign_key "group_managements", "groups"
  add_foreign_key "group_managements", "users"
  add_foreign_key "group_members", "groups"
  add_foreign_key "group_members", "transporters"
  add_foreign_key "interactions", "groups"
  add_foreign_key "interactions", "internal_events"
  add_foreign_key "interactions", "messages"
  add_foreign_key "interactions", "transporters"
  add_foreign_key "internal_events", "bot_connections"
  add_foreign_key "internal_events", "raw_events"
  add_foreign_key "messages", "bot_accounts"
  add_foreign_key "messages", "contents"
  add_foreign_key "messages", "groups"
  add_foreign_key "messages", "internal_events"
  add_foreign_key "messages", "transporters"
  add_foreign_key "raw_events", "bot_connections"
  add_foreign_key "reports", "shit_entries"
  add_foreign_key "reports", "users"
  add_foreign_key "reports", "users", column: "reviewer_id"
  add_foreign_key "safety_decisions", "shit_entries"
  add_foreign_key "safety_decisions", "users"
  add_foreign_key "shit_entries", "contents"
  add_foreign_key "shit_entries", "groups", column: "first_group_id"
  add_foreign_key "shit_entries", "shit_entries", column: "merged_into_id"
  add_foreign_key "shit_entries", "transporters", column: "first_transporter_id"
  add_foreign_key "shit_occurrences", "deliveries"
  add_foreign_key "shit_occurrences", "groups"
  add_foreign_key "shit_occurrences", "messages"
  add_foreign_key "shit_occurrences", "shit_entries"
  add_foreign_key "shit_occurrences", "transporters"
  add_foreign_key "shit_occurrences", "trial_runs"
  add_foreign_key "simulation_actions", "simulation_runs"
  add_foreign_key "simulation_runs", "users"
  add_foreign_key "timeline_events", "groups"
  add_foreign_key "timeline_events", "shit_entries"
  add_foreign_key "timeline_events", "transporters"
  add_foreign_key "trial_deliveries", "deliveries"
  add_foreign_key "trial_deliveries", "groups"
  add_foreign_key "trial_deliveries", "trial_runs"
  add_foreign_key "trial_results", "trial_runs"
  add_foreign_key "trial_runs", "shit_entries"
  add_foreign_key "web_ratings", "shit_entries"
  add_foreign_key "web_ratings", "users"
end
