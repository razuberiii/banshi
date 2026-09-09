require_relative '../domain_helpers'
class PersistentJobsTest < ActiveSupport::TestCase
  include DomainHelpers
  test 'GoodJob persists a due job and executes it against PostgreSQL' do
    previous=ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter=:good_job
    person=domain_transporter
    job=ReputationRefreshJob.set(queue:'verification').perform_later(person.id)
    stored=GoodJob::Job.find_by!(active_job_id:job.job_id)
    assert_nil stored.finished_at
    GoodJob.perform_inline('verification',limit:1)
    assert stored.reload.finished_at
    assert_nil stored.error
    assert person.reload.reputation_details.key?('settled_samples')
  ensure
    ActiveJob::Base.queue_adapter=previous
  end
end
