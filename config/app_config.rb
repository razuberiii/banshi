require 'json'
require 'uri'
# Single configuration boundary. Business code never reads ENV.
module AppConfig
  class Invalid < StandardError; end
  SCHEMA = JSON.parse(File.read(File.join(__dir__, 'app_config_schema.json'))).freeze
  class Section
    def initialize(values) = @values = values.freeze
    def method_missing(name, *args) = args.empty? && @values.key?(name.to_sym) ? @values[name.to_sym] : super
    def respond_to_missing?(name, *) = @values.key?(name.to_sym)
    def to_h = @values.dup
  end
  def self.load(source = ENV.to_h)
    values = SCHEMA.to_h do |section, entries|
      [section.to_sym, Section.new(entries.to_h do |key, (env_key, type, default)|
        raw = source.key?(env_key) && !source[env_key].to_s.empty? ? source[env_key] : default
        [key.to_sym, convert(type, raw, env_key)]
      end)]
    end
    settings = Section.new(values)
    validate!(settings)
    settings
  end
  def self.convert(type, value, key)
    case type
    when 'integer' then Integer(value)
    when 'float' then Float(value).tap { |v| raise Invalid, "#{key} must be finite" unless v.finite? }
    when 'minutes' then Integer(value) * 60
    when 'hours' then Integer(value) * 3600
    when 'days' then Integer(value) * 86_400
    when 'boolean'
      return value if value == true || value == false
      return true if %w[true 1 yes on].include?(value.to_s.downcase)
      return false if %w[false 0 no off].include?(value.to_s.downcase)
      raise Invalid, "#{key} must be true or false"
    when 'list'
      parsed = value.is_a?(Array) ? value : value.to_s.start_with?('[') ? JSON.parse(value) : value.to_s.split(',').map(&:strip)
      raise Invalid, "#{key} must be a string list" unless parsed.is_a?(Array) && parsed.all? { |v| v.is_a?(String) }
      parsed.freeze
    when 'json'
      parsed = value.is_a?(Hash) ? value : JSON.parse(value)
      raise Invalid, "#{key} must be a JSON object" unless parsed.is_a?(Hash)
      parsed.freeze
    else value.to_s.freeze
    end
  rescue ArgumentError, TypeError, JSON::ParserError
    raise Invalid, "Invalid #{key} (expected #{type})"
  end
  def self.validate!(c)
    SCHEMA.each do |section, entries|
      entries.each do |key, (env_key, type, _)|
        value = c.public_send(section).public_send(key)
        raise Invalid, "#{env_key} cannot be negative" if %w[integer float minutes hours days].include?(type) && value.negative?
      end
    end
    { 'CANDIDATE_TTL_MINUTES'=>c.candidate.ttl, 'CANDIDATE_MIN_SCORE'=>c.candidate.min_score, 'DATABASE_POOL'=>c.database.pool,
      'PAGE_SIZE'=>c.system.page_size, 'CLAIM_TTL_MINUTES'=>c.claim.ttl, 'CLAIM_TOKEN_LENGTH'=>c.claim.token_length,
      'TRIAL_DURATION_MINUTES'=>c.trial.duration, 'JOB_THREADS'=>c.jobs.threads }.each { |k,v| raise Invalid,"#{k} must be positive" unless v.positive? }
    raise Invalid, 'TRIAL_GROUP_MIN/MAX must be ordered and positive' unless c.trial.group_min.positive? && c.trial.group_min <= c.trial.group_max
    raise Invalid, 'Duplicate thresholds must be ordered in 0..64' unless (0..64).cover?(c.duplicate.phash_threshold) && (c.duplicate.phash_threshold..64).cover?(c.duplicate.possible_threshold)
    raise Invalid, 'Reputation prior must be positive' unless c.reputation.prior_successes.positive? && c.reputation.prior_failures.positive?
    raise Invalid, 'Safety default must be GREEN, YELLOW or RED' unless %w[GREEN YELLOW RED].include?(c.safety.default_level)
    raise Invalid, 'Safety visibility must be public, hidden or metadata_only' unless %w[public hidden metadata_only].include?(c.safety.default_visibility)
    raise Invalid, 'Storage provider must be local or s3' unless %w[local s3].include?(c.storage.provider)
    raise Invalid, 'S3 requires a bucket' if c.storage.provider == 's3' && c.storage.bucket.empty?
    raise Invalid, 'Trial reaction definitions must be distinct' unless [c.trial.reaction_good,c.trial.reaction_funny,c.trial.reaction_bad].uniq.length == 3
    raise Invalid, 'CLAIM_TOKEN_LENGTH must be in 6..32' unless (6..32).cover?(c.claim.token_length)
    raise Invalid, 'PAGE_SIZE must be in 1..100' unless (1..100).cover?(c.system.page_size)
    raise Invalid, 'Candidate must require at least one independent user' unless c.candidate.min_unique_users.positive?
    %i[max_forward_depth max_forward_nodes max_forward_media max_media_pixels max_media_bytes request_timeout].each do |key|
      raise Invalid,"NAPCAT_#{key.upcase} must be positive" unless c.napcat.public_send(key).positive?
    end
    raise Invalid,'Safety hard tags must be defined' unless (c.safety.hard_block_tags-c.safety.tags).empty?
    raise Invalid,'Report threshold must be positive' unless c.safety.report_pause_threshold.positive?
    unless c.modes.rules.all? { |name,rule| !name.empty? && rule.is_a?(Hash) && %w[collect distribute].all? { |key| [true,false].include?(rule[key]) } }
      raise Invalid,'BOT_MODE_RULES must map names to collect/distribute booleans'
    end
    raise Invalid,'NAPCAT_REACTION_MAP must map IDs to nonempty strings' unless c.napcat.reaction_map.values.all? { |value| value.is_a?(String) && !value.empty? }
    [c.trial.positive_threshold,c.trial.negative_max].each { |v| raise Invalid, 'Trial rates must be in 0..1' unless (0..1).cover?(v) }
    if c.system.environment == 'production'
      raise Invalid, 'Set a unique SECRET_KEY_BASE (64+ chars)' if c.system.secret_key_base.length < 64 || c.system.secret_key_base.start_with?('development-only')
      raise Invalid, 'Disable DEMO_ENABLED and SEED_DEMO in production' if c.demo.enabled || c.demo.seed
    end
    raise Invalid, 'NAPCAT_ENABLED requires access and webhook tokens' if c.napcat.enabled && [c.napcat.access_token,c.napcat.webhook_token].any?(&:empty?)
    c
  end
  def self.current = Thread.current[:banshi_config] || (@current ||= load)
  def self.reset! = @current = load
  def self.with(overrides)
    previous = Thread.current[:banshi_config]
    values = current.to_h
    overrides.each { |s, kv| values[s.to_sym] = Section.new(values.fetch(s.to_sym).to_h.merge(kv.transform_keys(&:to_sym))) }
    Thread.current[:banshi_config] = validate!(Section.new(values))
    yield
  ensure
    Thread.current[:banshi_config] = previous
  end
  def self.method_missing(name, *args) = args.empty? && current.respond_to?(name) ? current.public_send(name) : super
  def self.respond_to_missing?(name, *) = SCHEMA.key?(name.to_s)
end
