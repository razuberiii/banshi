class SimulationRun < ApplicationRecord
  belongs_to :user
  has_many :simulation_actions,dependent: :destroy
  def candidate = Candidate.find_by(id:state['candidate_id'])
  def entry = ShitEntry.find_by(id:state['entry_id']) || candidate&.shit_entry
end
