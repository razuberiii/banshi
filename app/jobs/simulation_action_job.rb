class SimulationActionJob < ApplicationJob
  def perform(id) = SimulationProcessor.call(SimulationAction.find(id))
end
