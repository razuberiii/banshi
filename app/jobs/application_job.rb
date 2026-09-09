class ApplicationJob < ActiveJob::Base
  retry_on StandardError, wait: :polynomially_longer, attempts: AppConfig.jobs.attempts do |job,error|
    DomainLog.error(error,context:'job_exhausted',job_class:job.class.name,job_id:job.job_id)
  end
  around_perform do |job,block|
    DomainLog.emit('job.started',job_class:job.class.name,job_id:job.job_id)
    block.call
  rescue StandardError=>error
    DomainLog.error(error,context:'job',job_class:job.class.name,job_id:job.job_id)
    raise
  end
end
