class GroupMember < ApplicationRecord
  belongs_to :group, class_name: "Group"
  belongs_to :transporter, class_name: "Transporter"
end
