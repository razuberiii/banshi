Rails.application.configure do
  config.enable_reloading = false
  config.active_record.maintain_test_schema = AppConfig.database.maintain_test_schema
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.allow_forgery_protection = false
  config.active_job.queue_adapter = :test
  config.active_support.deprecation = :stderr
  config.hosts.clear
end
