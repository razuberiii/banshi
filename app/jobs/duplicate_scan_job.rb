class DuplicateScanJob < ApplicationJob
  def perform(content_id) = DuplicateDetector.call(content:Content.find(content_id))
end
