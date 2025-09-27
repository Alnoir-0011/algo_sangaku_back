class ApiKey < ApplicationRecord
  belongs_to :user

  validates :access_token, presence: true, uniqueness: true

  # scope :active, -> { where("expires_at >= ?", Time.current) }

  def initialize(attributes = {})
    super
    self.access_token = SecureRandom.uuid
    # self.expires_at = 1.week.after
  end
end
