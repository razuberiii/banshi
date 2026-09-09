class LeaderboardRefreshJob < ApplicationJob
  queue_as :statistics
  def perform = LeaderboardRefresh.call
end
