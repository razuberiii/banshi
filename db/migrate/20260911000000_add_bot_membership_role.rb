class AddBotMembershipRole < ActiveRecord::Migration[8.0]
  def change
    add_column :group_bot_memberships, :role, :string, null: false, default: 'member'
  end
end
