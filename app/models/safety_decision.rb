class SafetyDecision < ApplicationRecord
  belongs_to :shit_entry, class_name: "ShitEntry"
  belongs_to :user, class_name: "User", optional: true
end
