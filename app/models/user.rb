class User < ApplicationRecord
  has_secure_password
  has_many :group_managements, dependent: :destroy
  has_many :managed_groups, through: :group_managements, source: :group
  has_many :favorites, dependent: :destroy
  has_many :web_ratings, dependent: :destroy
  has_many :claim_tokens, dependent: :destroy
  before_validation { self.email = email.to_s.strip.downcase; self.public_id ||= SecureRandom.hex(8) }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { maximum: 40 }
  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :site_role, inclusion: { in: %w[member curator] }
  def curator? = site_role == 'curator'
  def manages?(group) = curator? || group_managements.exists?(group_id: group.id)
  def to_param = public_id
end
