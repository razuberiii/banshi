class GroupStatsRefreshJob < ApplicationJob
  queue_as :statistics
  def perform(group_id = nil)
    scope = group_id ? Group.where(id: group_id) : Group.all
    scope.find_each { |group| GroupStatsRefresh.call(group) }
  end
end
