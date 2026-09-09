class AuditLog < ApplicationRecord
  belongs_to :user, class_name: "User", optional: true
  belongs_to :group, class_name: "Group", optional: true
  belongs_to :shit_entry, class_name: "ShitEntry", optional: true
end
