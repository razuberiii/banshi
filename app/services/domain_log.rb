class DomainLog
  def self.emit(event, **data)
    Rails.logger.info({ event: event, timestamp: Time.current.iso8601 }.merge(data).to_json)
  end
  def self.error(error, context:, **details)
    emit('error', context: context, error_class: error.class.name, message: error.message.to_s.first(500), **details)
    SystemError.create!(context: context, error_class: error.class.name, message: error.message.to_s.first(1000), details: details)
  end
end
