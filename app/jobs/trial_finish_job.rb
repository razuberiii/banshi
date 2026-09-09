class TrialFinishJob < ApplicationJob
  queue_as :distribution
  def perform(run_id = nil)
    scope = run_id ? TrialRun.where(id: run_id) : TrialRun.where(status: 'running').where('ends_at <= ?', Time.current)
    scope.find_each { |run| TrialEvaluator.call(run: run) }
  end
end
