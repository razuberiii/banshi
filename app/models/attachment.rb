class Attachment < ApplicationRecord
  belongs_to :content, class_name: "Content"
  belongs_to :asset, class_name: "Asset"
end
