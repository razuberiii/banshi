class ClassicEvaluationJob < ApplicationJob
  queue_as :statistics
  def perform(entry_id = nil)
    scope = entry_id ? ShitEntry.unmerged.where(id: entry_id) : ShitEntry.unmerged
    scope.find_each do |entry|
      ClassicEvaluator.call(entry)
      LevelEvaluator.call(entry)
    end
  end
end
