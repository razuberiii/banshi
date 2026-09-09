require_relative '../domain_helpers'
require Rails.root.join('db/migrate/20260909060000_use_explicit_group_participation')

class GroupPreferencesMigrationTest < ActiveSupport::TestCase
  include DomainHelpers

  test 'upgrade replaces card fallback with self service while preserving explicit choices and group history' do
    legacy=domain_group
    configured=domain_group(collect_enabled:false,distribute_enabled:true)
    message=domain_message(group:legacy)
    migration=UseExplicitGroupParticipation.new
    migration.suppress_messages do
      migration.down
      Group.connection.execute("UPDATE groups SET mode = '搬💩', collect_enabled = NULL, distribute_enabled = NULL WHERE id = #{legacy.id}")
      migration.up
    end
    Group.reset_column_information
    assert_equal [true,true],legacy.reload.attributes.values_at('collect_enabled','distribute_enabled')
    assert_equal [false,true],configured.reload.attributes.values_at('collect_enabled','distribute_enabled')
    assert_equal legacy.id,message.reload.group_id
    assert_equal true,Group.columns_hash.fetch('collect_enabled').default == 'true'
    refute Group.columns_hash.fetch('distribute_enabled').null
  ensure
    Group.reset_column_information
  end
end
