class EntryMerge < ApplicationRecord
  belongs_to :source, class_name: "ShitEntry"
  belongs_to :target, class_name: "ShitEntry"
  belongs_to :user, class_name: "User"
end
