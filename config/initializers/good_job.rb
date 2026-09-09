Rails.application.configure do
  config.good_job.execution_mode = :external
  config.good_job.max_threads = AppConfig.jobs.threads
  config.good_job.poll_interval = AppConfig.jobs.poll_interval
  config.good_job.enable_cron = AppConfig.jobs.cron_enabled
  config.good_job.preserve_job_records = true
  config.good_job.cron = {
    maintenance: { cron: AppConfig.jobs.maintenance_cron, class: 'MaintenanceSweepJob' },
    statistics: { cron: AppConfig.jobs.statistics_cron, class: 'StatisticsSweepJob' }
  }
end
