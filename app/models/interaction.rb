class Interaction < ApplicationRecord
  belongs_to :group, class_name: "Group"
  belongs_to :transporter, class_name: "Transporter"
  belongs_to :message, class_name: "Message", optional: true
  belongs_to :internal_event, class_name: "InternalEvent", optional: true
end
