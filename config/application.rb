require_relative 'boot'
require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rails/test_unit/railtie'
# Load Nokogiri's bundled libxml before libvips. On Linux the reverse order
# can bind HTML5 XPath to libvips' older system libxml symbols.
require 'nokogiri'
Bundler.require(*Rails.groups)
require_relative 'app_config'
module Banshi
  class Application < Rails::Application
    config.load_defaults 8.0
    config.time_zone = AppConfig.system.time_zone
    config.active_record.default_timezone = :utc
    config.active_job.queue_adapter = :good_job
    config.autoload_lib(ignore: %w[assets tasks])
    config.secret_key_base = AppConfig.system.secret_key_base
    config.hosts = AppConfig.system.allowed_hosts.dup unless AppConfig.system.allowed_hosts.empty?
    config.generators.system_tests = nil
    config.action_dispatch.rescue_responses['AppConfig::Invalid'] = :unprocessable_entity
    config.filter_parameters += %i[password password_confirmation token access_token external_id payload email]
  end
end
