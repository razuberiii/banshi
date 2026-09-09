class CandidateExpireJob < ApplicationJob
  queue_as :collection
  def perform(candidate_id = nil)
    scope = candidate_id ? Candidate.pending.where(id: candidate_id) : Candidate.due
    scope.find_each { |candidate| CandidateEvaluator.call(candidate: candidate) }
  end
end
