class Asset < ApplicationRecord
  belongs_to :original_asset, class_name: 'Asset', optional: true
  has_many :attachments
  has_many :contents, through: :attachments
  validates :sha256, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :storage_key, presence: true, uniqueness: true
  validates :visibility, inclusion: { in: %w[visible hidden redacted] }
end
