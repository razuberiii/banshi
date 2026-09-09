class Transporter < ApplicationRecord
  has_many :group_members
  has_many :groups, through: :group_members
  has_many :candidates
  has_many :shit_occurrences
  has_many :discoveries, class_name: 'ShitEntry', foreign_key: :first_transporter_id
  before_validation { self.public_id ||= SecureRandom.hex(8) }
  validates :external_id, presence: true, uniqueness: true
  validates :display_name, presence: true
  scope :public_profiles, -> { where(public_profile: true) }
  def to_param = public_id
  def title
    return '识屎伯乐' if classic_count.positive?
    return '互联网下水道勘探员' if natural_count >= 10
    return '厕所守望者' if accepted_count.positive?
    '新晋勘探员'
  end
end
