class ApiKey < ApplicationRecord
  belongs_to :user

  validates :access_token, presence: true, uniqueness: true

  scope :active, -> { where("expires_at >= ?", Time.current) }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.access_token = SecureRandom.uuid
    self.expires_at = 1.week.after
  end
end
