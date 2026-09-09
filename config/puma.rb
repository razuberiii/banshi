require_relative 'app_config'
threads AppConfig.system.web_threads, AppConfig.system.web_threads
port AppConfig.system.port
environment AppConfig.system.environment
pidfile 'tmp/pids/server.pid'
plugin :tmp_restart
