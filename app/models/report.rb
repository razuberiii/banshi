class Report < ApplicationRecord
  REASONS = { 'privacy'=>'隐私泄露', 'gore'=>'血腥暴力', 'sexual'=>'色情', 'minors'=>'未成年人', 'harassment'=>'人身攻击', 'illegal'=>'违法内容', 'misclassification'=>'错误归类', 'ownership'=>'本人内容要求处理', 'other'=>'其他' }.freeze
  belongs_to :shit_entry
  belongs_to :user
  belongs_to :reviewer, class_name: 'User', optional: true
  validates :reason, inclusion: { in: REASONS.keys }
  validates :details, length: { maximum: 3000 }
  validates :status, inclusion: { in: %w[open resolved dismissed] }
end
