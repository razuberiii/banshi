class EventProcessJob < ApplicationJob
  def perform(id) = Events::Processor.call(InternalEvent.find(id))
end
