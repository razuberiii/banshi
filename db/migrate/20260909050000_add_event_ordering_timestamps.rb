class AddEventOrderingTimestamps < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :mode_event_at, :datetime
    add_column :groups, :mode_event_id, :bigint
    [:group_bot_memberships, :group_members].each do |table|
      add_column table, :membership_event_at, :datetime
      add_column table, :membership_event_id, :bigint
    end
    add_column :group_bot_memberships, :card_event_at, :datetime
    add_column :group_bot_memberships, :card_event_id, :bigint
    add_column :group_members, :role_event_at, :datetime
    add_column :group_members, :role_event_id, :bigint
  end
end
