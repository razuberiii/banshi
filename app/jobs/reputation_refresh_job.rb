class ReputationRefreshJob < ApplicationJob
  queue_as :statistics
  def perform(transporter_id = nil)
    scope = transporter_id ? Transporter.where(id: transporter_id) : Transporter.all
    scope.find_each { |transporter| ReputationCalculator.call(transporter) }
  end
end
