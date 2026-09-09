class Content < ApplicationRecord
  has_many :attachments, -> { order(:position) }, dependent: :destroy
  has_many :assets, through: :attachments
  has_many :forward_nodes, -> { order(:position) }, dependent: :destroy
  has_many :candidates
  has_many :shit_entries
  validates :kind, :fingerprint, presence: true
  def image? = kind == 'image'
  def forward? = kind == 'forward'
end
