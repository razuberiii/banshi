class UseExplicitGroupParticipation < ActiveRecord::Migration[8.0]
  def up
    # NULL used to mean "follow the bot card". It now adopts self-service
    # defaults; explicit administrator choices (including false) are retained.
    execute 'UPDATE groups SET collect_enabled = TRUE WHERE collect_enabled IS NULL'
    execute 'UPDATE groups SET distribute_enabled = TRUE WHERE distribute_enabled IS NULL'
    change_column_default :groups, :collect_enabled, from: nil, to: true
    change_column_default :groups, :distribute_enabled, from: nil, to: true
    change_column_null :groups, :collect_enabled, false
    change_column_null :groups, :distribute_enabled, false
    remove_column :groups, :mode
    remove_column :groups, :mode_event_at
    remove_column :groups, :mode_event_id
    change_column_default :group_bot_memberships, :card, from: '自助餐', to: ''
  end

  def down
    add_column :groups, :mode, :string, null: false, default: '自助餐'
    add_column :groups, :mode_event_at, :datetime
    add_column :groups, :mode_event_id, :bigint
    change_column_null :groups, :collect_enabled, true
    change_column_null :groups, :distribute_enabled, true
    change_column_default :groups, :collect_enabled, from: true, to: nil
    change_column_default :groups, :distribute_enabled, from: true, to: nil
    change_column_default :group_bot_memberships, :card, from: '', to: '自助餐'
    # Keep materialized choices on rollback: do not silently reopen or close
    # a group based on a display name. Historical card audit rows stay intact.
  end
end
