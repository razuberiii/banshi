class StatisticsSweepJob < ApplicationJob
  def perform
    ReputationRefreshJob.perform_later
    ClassicEvaluationJob.perform_later
    GroupStatsRefreshJob.perform_later
    LeaderboardRefreshJob.perform_later
  end
end
