class TrialResult < ApplicationRecord
  belongs_to :trial_run, class_name: "TrialRun"
end
