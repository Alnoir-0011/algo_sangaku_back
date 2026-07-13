class ApiKey < ApplicationRecord
  attribute :raw_token, :string

  belongs_to :user

  validates :access_token, presence: true, uniqueness: true

  scope :active, -> { where("expires_at >= ?", Time.current) }

  after_initialize :set_defaults, if: :new_record?

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  private

  def set_defaults
    self.raw_token = SecureRandom.uuid
    self.access_token = ApiKey.digest(raw_token)
    self.expires_at = 1.week.after
  end
end
