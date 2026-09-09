class CreateArchiveDomain < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pg_trgm'
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :display_name, null: false
      t.string :site_role, null: false, default: "member"
      t.string :public_id, null: false
      t.timestamps
    end
    create_table :bot_accounts do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    create_table :bot_connections do |t|
      t.references :bot_account, null: false, foreign_key: { to_table: :bot_accounts }
      t.string :name, null: false
      t.string :adapter, null: false, default: "fake"
      t.string :status, null: false, default: "online"
      t.string :endpoint, null: true
      t.string :credential_env_key, null: true
      t.datetime :last_seen_at, null: true
      t.jsonb :capabilities, null: false, default: {}
      t.timestamps
    end
    create_table :groups do |t|
      t.string :external_id, null: false
      t.string :slug, null: false
      t.string :public_name, null: false
      t.string :anonymous_name, null: false
      t.text :description, null: true
      t.string :visibility, null: false, default: "statistics"
      t.boolean :anonymous, null: false, default: true
      t.boolean :hide_members, null: false, default: true
      t.string :mode, null: false, default: "自助餐"
      t.boolean :collect_enabled, null: true
      t.boolean :distribute_enabled, null: true
      t.string :trial_preference, null: false, default: "FALLBACK"
      t.integer :daily_limit, null: true
      t.integer :cooldown_minutes, null: true
      t.string :accepted_tags, null: false, array: true, default: []
      t.boolean :accept_hot, null: false, default: true
      t.boolean :accept_classic, null: false, default: true
      t.boolean :accept_archaeology, null: false, default: false
      t.datetime :joined_at, null: false
      t.datetime :last_delivery_at, null: true
      t.datetime :last_trial_at, null: true
      t.jsonb :stats, null: false, default: {}
      t.timestamps
    end
    create_table :group_bot_memberships do |t|
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :bot_account, null: false, foreign_key: { to_table: :bot_accounts }
      t.string :card, null: false, default: "自助餐"
      t.boolean :active, null: false, default: true
      t.datetime :joined_at, null: false
      t.timestamps
    end
    create_table :transporters do |t|
      t.string :external_id, null: false
      t.string :public_id, null: false
      t.string :display_name, null: false
      t.boolean :public_profile, null: false, default: false
      t.integer :candidate_count, null: false, default: 0
      t.integer :accepted_count, null: false, default: 0
      t.integer :natural_count, null: false, default: 0
      t.integer :classic_count, null: false, default: 0
      t.float :reputation_score, null: false, default: 0.5
      t.jsonb :reputation_details, null: false, default: {}
      t.timestamps
    end
    create_table :group_members do |t|
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :transporter, null: false, foreign_key: { to_table: :transporters }
      t.string :role, null: false, default: "member"
      t.string :display_name, null: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    create_table :group_managements do |t|
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.string :verified_role, null: false
      t.datetime :verified_at, null: false
      t.timestamps
    end
    create_table :contents do |t|
      t.string :kind, null: false
      t.string :fingerprint, null: false
      t.text :text_body, null: true
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    create_table :assets do |t|
      t.string :sha256, null: false
      t.string :phash, null: true
      t.string :storage_key, null: false
      t.string :content_type, null: false
      t.integer :width, null: true
      t.integer :height, null: true
      t.bigint :byte_size, null: false
      t.string :visibility, null: false, default: "visible"
      t.references :original_asset, null: true, foreign_key: { to_table: :assets }
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    create_table :attachments do |t|
      t.references :content, null: false, foreign_key: { to_table: :contents }
      t.references :asset, null: false, foreign_key: { to_table: :assets }
      t.integer :position, null: false, default: 0
      t.string :role, null: false, default: "original"
      t.timestamps
    end
    create_table :forward_nodes do |t|
      t.references :content, null: false, foreign_key: { to_table: :contents }
      t.references :parent, null: true, foreign_key: { to_table: :forward_nodes }
      t.integer :position, null: false
      t.string :display_name, null: false, default: "匿名群友"
      t.text :body, null: true
      t.datetime :sent_at, null: true
      t.references :asset, null: true, foreign_key: { to_table: :assets }
      t.timestamps
    end
    create_table :raw_events do |t|
      t.references :bot_connection, null: false, foreign_key: { to_table: :bot_connections }
      t.string :digest, null: false
      t.jsonb :payload, null: false
      t.datetime :received_at, null: false
      t.timestamps
    end
    create_table :internal_events do |t|
      t.references :raw_event, null: true, foreign_key: { to_table: :raw_events }
      t.references :bot_connection, null: true, foreign_key: { to_table: :bot_connections }
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.string :group_external_id, null: true
      t.string :sender_external_id, null: true
      t.string :message_external_id, null: true
      t.string :reply_to_message_id, null: true
      t.string :content_type, null: true
      t.datetime :occurred_at, null: false
      t.jsonb :media_references, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.text :error_message, null: true
      t.timestamps
    end
    create_table :messages do |t|
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :transporter, null: true, foreign_key: { to_table: :transporters }
      t.references :bot_account, null: true, foreign_key: { to_table: :bot_accounts }
      t.references :internal_event, null: true, foreign_key: { to_table: :internal_events }
      t.references :content, null: true, foreign_key: { to_table: :contents }
      t.string :external_id, null: false
      t.string :reply_to_external_id, null: true
      t.string :source, null: false, default: "NATURAL"
      t.string :kind, null: false, default: "text"
      t.text :body, null: true
      t.datetime :sent_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    create_table :shit_entries do |t|
      t.references :content, null: false, foreign_key: { to_table: :contents }
      t.references :first_group, null: false, foreign_key: { to_table: :groups }
      t.references :first_transporter, null: true, foreign_key: { to_table: :transporters }
      t.string :sid, null: false
      t.string :title, null: true
      t.text :summary, null: true
      t.string :level, null: false, default: "ARCHIVED"
      t.string :safety_level, null: false, default: "RED"
      t.string :safety_tags, null: false, array: true, default: []
      t.string :visibility, null: false, default: "hidden"
      t.boolean :distribution_paused, null: false, default: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_natural_at, null: false
      t.datetime :first_distributed_at, null: true
      t.datetime :classic_at, null: true
      t.integer :natural_count, null: false, default: 0
      t.integer :bot_count, null: false, default: 0
      t.integer :natural_group_count, null: false, default: 0
      t.integer :interaction_count, null: false, default: 0
      t.integer :revival_count, null: false, default: 0
      t.float :distribution_score, null: false, default: 0
      t.references :merged_into, null: true, foreign_key: { to_table: :shit_entries }
      t.timestamps
    end
    create_table :candidates do |t|
      t.references :message, null: false, foreign_key: { to_table: :messages }
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :transporter, null: true, foreign_key: { to_table: :transporters }
      t.references :content, null: false, foreign_key: { to_table: :contents }
      t.references :shit_entry, null: true, foreign_key: { to_table: :shit_entries }
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :evaluated_at, null: true
      t.float :score, null: false, default: 0
      t.float :reputation_snapshot, null: false, default: 0.5
      t.string :decision_reason, null: true
      t.jsonb :rule_results, null: false, default: {}
      t.string :duplicate_status, null: true
      t.float :duplicate_confidence, null: true
      t.timestamps
    end
    create_table :trial_runs do |t|
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.string :status, null: false, default: "pending"
      t.datetime :started_at, null: true
      t.datetime :ends_at, null: true
      t.datetime :finished_at, null: true
      t.string :strategy, null: false, default: "rotating_opt_in"
      t.jsonb :explanation, null: false, default: {}
      t.timestamps
    end
    create_table :deliveries do |t|
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :bot_connection, null: false, foreign_key: { to_table: :bot_connections }
      t.references :trial_run, null: true, foreign_key: { to_table: :trial_runs }
      t.references :message, null: true, foreign_key: { to_table: :messages }
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false
      t.string :external_message_id, null: true
      t.datetime :sent_at, null: true
      t.text :error_message, null: true
      t.jsonb :decision, null: false, default: {}
      t.timestamps
    end
    create_table :trial_deliveries do |t|
      t.references :trial_run, null: false, foreign_key: { to_table: :trial_runs }
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :delivery, null: false, foreign_key: { to_table: :deliveries }
      t.string :feedback_state, null: false, default: "unknown"
      t.jsonb :stats, null: false, default: {}
      t.timestamps
    end
    create_table :trial_results do |t|
      t.references :trial_run, null: false, foreign_key: { to_table: :trial_runs }
      t.integer :trial_group_count, null: false, default: 0
      t.integer :responsive_group_count, null: false, default: 0
      t.integer :good_reactions, null: false, default: 0
      t.integer :funny_reactions, null: false, default: 0
      t.integer :bad_reactions, null: false, default: 0
      t.integer :unique_reply_users, null: false, default: 0
      t.integer :unique_interaction_users, null: false, default: 0
      t.float :positive_rate, null: false, default: 0
      t.float :negative_rate, null: false, default: 0
      t.float :responsive_group_rate, null: false, default: 0
      t.float :distribution_score, null: false, default: 0
      t.string :verdict, null: false
      t.jsonb :explanation, null: false, default: {}
      t.timestamps
    end
    create_table :shit_occurrences do |t|
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :transporter, null: true, foreign_key: { to_table: :transporters }
      t.references :message, null: false, foreign_key: { to_table: :messages }
      t.references :delivery, null: true, foreign_key: { to_table: :deliveries }
      t.references :trial_run, null: true, foreign_key: { to_table: :trial_runs }
      t.string :source, null: false
      t.datetime :occurred_at, null: false
      t.boolean :first_appearance, null: false, default: false
      t.boolean :duplicate_matched, null: false, default: false
      t.float :match_confidence, null: true
      t.timestamps
    end
    create_table :interactions do |t|
      t.references :group, null: false, foreign_key: { to_table: :groups }
      t.references :transporter, null: false, foreign_key: { to_table: :transporters }
      t.references :message, null: true, foreign_key: { to_table: :messages }
      t.references :internal_event, null: true, foreign_key: { to_table: :internal_events }
      t.string :target_external_id, null: false
      t.string :kind, null: false
      t.string :reaction, null: false, default: ''
      t.string :identity_key, null: false
      t.boolean :active, null: false, default: true
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    create_table :timeline_events do |t|
      t.references :shit_entry, null: true, foreign_key: { to_table: :shit_entries }
      t.references :group, null: true, foreign_key: { to_table: :groups }
      t.references :transporter, null: true, foreign_key: { to_table: :transporters }
      t.string :event_type, null: false
      t.string :label, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :details, null: false, default: {}
      t.string :dedupe_key, null: true
      t.timestamps
    end
    create_table :safety_decisions do |t|
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.references :user, null: true, foreign_key: { to_table: :users }
      t.string :level, null: false
      t.string :tags, null: false, array: true, default: []
      t.string :source, null: false
      t.string :rule, null: true
      t.text :reason, null: false
      t.string :visibility, null: false
      t.datetime :decided_at, null: false
      t.timestamps
    end
    create_table :reports do |t|
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :reviewer, null: true, foreign_key: { to_table: :users }
      t.string :reason, null: false
      t.text :details, null: true
      t.string :status, null: false, default: "open"
      t.text :resolution, null: true
      t.datetime :reviewed_at, null: true
      t.timestamps
    end
    create_table :claim_tokens do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :group, null: true, foreign_key: { to_table: :groups }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at, null: true
      t.integer :attempts, null: false, default: 0
      t.timestamps
    end
    create_table :audit_logs do |t|
      t.references :user, null: true, foreign_key: { to_table: :users }
      t.references :group, null: true, foreign_key: { to_table: :groups }
      t.references :shit_entry, null: true, foreign_key: { to_table: :shit_entries }
      t.string :category, null: false
      t.string :action, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    create_table :web_ratings do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.string :reaction, null: false
      t.timestamps
    end
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.timestamps
    end
    create_table :duplicate_matches do |t|
      t.references :content, null: false, foreign_key: { to_table: :contents }
      t.references :shit_entry, null: false, foreign_key: { to_table: :shit_entries }
      t.string :method, null: false
      t.string :status, null: false, default: "possible"
      t.float :confidence, null: false
      t.integer :distance, null: true
      t.timestamps
    end
    create_table :entry_merges do |t|
      t.references :source, null: false, foreign_key: { to_table: :shit_entries }
      t.references :target, null: false, foreign_key: { to_table: :shit_entries }
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.jsonb :snapshot, null: false, default: {}
      t.text :reason, null: false
      t.datetime :reverted_at, null: true
      t.timestamps
    end
    create_table :leaderboard_snapshots do |t|
      t.string :board, null: false
      t.datetime :generated_at, null: false
      t.jsonb :rows, null: false, default: []
      t.timestamps
    end
    create_table :system_errors do |t|
      t.string :context, null: false
      t.string :error_class, null: false
      t.text :message, null: true
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :users, [:public_id], name: :idx_users_0, unique: true
    add_index :bot_accounts, [:external_id], name: :idx_bot_accounts_0, unique: true
    add_index :groups, [:external_id], name: :idx_groups_0, unique: true
    add_index :groups, [:slug], name: :idx_groups_1, unique: true
    add_index :groups, [:visibility, :joined_at], name: :idx_groups_2
    add_index :groups, [:trial_preference, :last_trial_at], name: :idx_groups_3
    add_index :group_bot_memberships, [:group_id, :bot_account_id], name: :idx_group_bot_memberships_0, unique: true
    add_index :transporters, [:external_id], name: :idx_transporters_0, unique: true
    add_index :transporters, [:public_id], name: :idx_transporters_1, unique: true
    add_index :group_members, [:group_id, :transporter_id], name: :idx_group_members_0, unique: true
    add_index :group_managements, [:group_id, :user_id], name: :idx_group_managements_0, unique: true
    add_index :contents, [:fingerprint], name: :idx_contents_0
    add_index :assets, [:sha256], name: :idx_assets_0, unique: true
    add_index :assets, [:storage_key], name: :idx_assets_1, unique: true
    add_index :assets, [:phash], name: :idx_assets_2
    add_index :attachments, [:content_id, :position], name: :idx_attachments_0, unique: true
    add_index :forward_nodes, [:content_id, :position], name: :idx_forward_nodes_0, unique: true
    add_index :raw_events, [:bot_connection_id, :digest], name: :idx_raw_events_0, unique: true
    add_index :internal_events, [:event_id], name: :idx_internal_events_0, unique: true
    add_index :internal_events, [:status, :occurred_at], name: :idx_internal_events_1
    add_index :internal_events, [:group_external_id, :message_external_id], name: :idx_internal_events_2
    add_index :messages, [:group_id, :external_id], name: :idx_messages_0, unique: true
    add_index :messages, [:group_id, :sent_at], name: :idx_messages_1
    add_index :shit_entries, [:sid], name: :idx_shit_entries_0, unique: true
    add_index :shit_entries, [:visibility, :level, :first_seen_at], name: :idx_shit_entries_1
    add_index :shit_entries, [:natural_count, :last_natural_at], name: :idx_shit_entries_2
    add_index :candidates, [:status, :expires_at], name: :idx_candidates_0
    add_index :trial_runs, [:status, :ends_at], name: :idx_trial_runs_0
    add_index :deliveries, [:idempotency_key], name: :idx_deliveries_0, unique: true
    add_index :deliveries, [:group_id, :created_at], name: :idx_deliveries_1
    add_index :deliveries, [:shit_entry_id, :group_id], name: :idx_deliveries_2
    add_index :trial_deliveries, [:trial_run_id, :group_id], name: :idx_trial_deliveries_0, unique: true
    add_index :shit_occurrences, [:shit_entry_id, :source, :occurred_at], name: :idx_shit_occurrences_0
    add_index :shit_occurrences, [:group_id, :source, :occurred_at], name: :idx_shit_occurrences_1
    add_index :interactions, [:identity_key], name: :idx_interactions_0, unique: true
    add_index :interactions, [:group_id, :target_external_id, :active], name: :idx_interactions_1
    add_index :timeline_events, [:shit_entry_id, :occurred_at], name: :idx_timeline_events_0
    add_index :timeline_events, [:dedupe_key], name: :idx_timeline_events_1, unique: true
    add_index :claim_tokens, [:token_digest], name: :idx_claim_tokens_0, unique: true
    add_index :claim_tokens, [:expires_at, :used_at], name: :idx_claim_tokens_1
    add_index :audit_logs, [:category, :created_at], name: :idx_audit_logs_0
    add_index :web_ratings, [:user_id, :shit_entry_id, :reaction], name: :idx_web_ratings_0, unique: true
    add_index :favorites, [:user_id, :shit_entry_id], name: :idx_favorites_0, unique: true
    add_index :duplicate_matches, [:content_id, :shit_entry_id], name: :idx_duplicate_matches_0, unique: true
    add_index :leaderboard_snapshots, [:board], name: :idx_leaderboard_snapshots_0, unique: true
    add_index :users, 'lower(email)', unique: true
    add_index :shit_entries, :safety_tags, using: :gin
    add_index :shit_entries, :title, using: :gin, opclass: :gin_trgm_ops
    add_index :candidates, :message_id, unique: true, name: :unique_candidate_message
    add_index :shit_occurrences, :message_id, unique: true, name: :unique_occurrence_message
    add_index :trial_results, :trial_run_id, unique: true, name: :unique_trial_result
    add_index :trial_runs, :shit_entry_id, unique: true, where: "status IN ('pending','running')", name: :one_active_trial_per_entry
    add_index :reports, [:shit_entry_id, :user_id], unique: true, where: "status = 'open'", name: :one_open_report_per_user_entry
    add_check_constraint :candidates, "status IN ('pending', 'accepted', 'expired', 'rejected', 'duplicate', 'unsafe')", name: :candidates_valid_status
    add_check_constraint :shit_entries, "level IN ('ARCHIVED', 'TRIAL', 'NORMAL', 'HOT', 'CLASSIC')", name: :shit_entries_valid_level
    add_check_constraint :shit_occurrences, "source IN ('NATURAL', 'BOT_TRIAL', 'BOT_DISTRIBUTION', 'BOT_CLASSIC')", name: :shit_occurrences_valid_source
    add_check_constraint :groups, "trial_preference IN ('OPT_IN', 'FALLBACK', 'OPT_OUT')", name: :groups_valid_trial_preference
  end
end
