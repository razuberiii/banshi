class DistributionJob < ApplicationJob
  queue_as :distribution
  def perform(entry_id = nil, kind = 'BOT_DISTRIBUTION')
    scope = entry_id ? ShitEntry.unmerged.where(id: entry_id) : ShitEntry.unmerged.where(level: %w[NORMAL HOT CLASSIC])
    scope.find_each { |entry| Distributor.call(entry: entry, kind: kind) }
  end
end
