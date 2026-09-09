class TrialDispatchJob < ApplicationJob
  queue_as :distribution
  def perform(entry_id)
    entry = ShitEntry.find_by(id: entry_id)
    TrialDispatcher.call(entry: entry) if entry
  end
end
