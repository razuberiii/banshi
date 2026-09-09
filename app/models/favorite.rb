class Favorite < ApplicationRecord
  belongs_to :user, class_name: "User"
  belongs_to :shit_entry, class_name: "ShitEntry"
end
