class CandidateEvaluateJob < ApplicationJob
  queue_as :collection
  def perform(candidate_id)
    candidate = Candidate.find_by(id: candidate_id)
    CandidateEvaluator.call(candidate: candidate) if candidate
  end
end
