Rails.application.config.middleware.use Rack::Attack
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
Rack::Attack.throttle('login/ip',limit:AppConfig.security.login_limit,period:AppConfig.security.rate_period) { |request|request.ip if request.post? && request.path=='/login' }
Rack::Attack.throttle('signup/ip',limit:AppConfig.security.signup_limit,period:AppConfig.security.signup_period) { |request|request.ip if request.post? && request.path=='/signup' }
Rack::Attack.throttle('claims/ip',limit:AppConfig.security.claim_limit,period:AppConfig.security.rate_period) { |request|request.ip if request.post? && request.path=='/claims' }
