class TrialDelivery < ApplicationRecord
  belongs_to :trial_run, class_name: "TrialRun"
  belongs_to :group, class_name: "Group"
  belongs_to :delivery, class_name: "Delivery"
end
