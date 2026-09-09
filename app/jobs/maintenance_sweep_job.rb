class MaintenanceSweepJob < ApplicationJob
  def perform
    CandidateExpireJob.perform_later
    TrialFinishJob.perform_later
    TrialRun.where(status:'pending').find_each { |run|TrialDispatchJob.perform_later(run.shit_entry_id) }
    Delivery.where(status:'pending').find_each { |delivery|DeliveryJob.perform_later(delivery.id) }
    Delivery.where(status:'sending').where('updated_at < ?',AppConfig.napcat.request_timeout.seconds.ago-60.seconds).find_each { |delivery|DeliveryJob.perform_later(delivery.id) }
    InternalEvent.where(status:%w[pending failed]).where('attempts < ?',AppConfig.jobs.attempts).find_each { |event|EventProcessJob.perform_later(event.id) }
    SimulationAction.where(status:'queued').find_each { |action|SimulationActionJob.perform_later(action.id) } if AppConfig.demo.enabled
    ExpiredClaimCleanupJob.perform_later
    DistributionJob.perform_later
    RawEvent.where('received_at < ?',Time.current-AppConfig.napcat.event_retention).find_each do |raw|
      raw.update_columns(payload:{redacted:true})
    end
  end
end
