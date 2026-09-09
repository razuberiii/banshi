class ForwardNode < ApplicationRecord
  belongs_to :content, class_name: "Content"
  belongs_to :parent, class_name: "ForwardNode", optional: true
  belongs_to :asset, class_name: "Asset", optional: true
end
