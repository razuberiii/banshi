Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = AppConfig.system.force_ssl
  config.assume_ssl = AppConfig.system.force_ssl
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
  config.log_level = :info
  config.active_support.report_deprecations = false
  config.public_file_server.enabled = true
end
