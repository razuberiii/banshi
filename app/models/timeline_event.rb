class TimelineEvent < ApplicationRecord
  belongs_to :shit_entry, class_name: "ShitEntry", optional: true
  belongs_to :group, class_name: "Group", optional: true
  belongs_to :transporter, class_name: "Transporter", optional: true
end
