class DuplicateMatch < ApplicationRecord
  belongs_to :content, class_name: "Content"
  belongs_to :shit_entry, class_name: "ShitEntry"
end
