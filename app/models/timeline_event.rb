class TimelineEvent < ApplicationRecord
  scope :public_associations, -> {
    AppConfig.features.public_groups ? where(group_id:Group.public_archives.select(:id)).or(where(group_id:nil)) : where(group_id:nil)
  }
  belongs_to :shit_entry, class_name: "ShitEntry", optional: true
  belongs_to :group, class_name: "Group", optional: true
  belongs_to :transporter, class_name: "Transporter", optional: true
end
