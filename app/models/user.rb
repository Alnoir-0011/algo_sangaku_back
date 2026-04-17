class User < ApplicationRecord
  has_many :sangakus, dependent: :destroy
  has_many :api_keys
  has_many :user_sangaku_saves, dependent: :destroy, class_name: "UserSangakuSave"
  has_many :saved_sangakus, through: :user_sangaku_saves, source: :sangaku
  has_many :answers, through: :user_sangaku_saves
  has_many :answer_results, through: :answers
  has_many :generate_source_call_logs, dependent: :destroy

  GENERATE_SOURCE_DAILY_LIMIT_DEFAULT = 5

  def generate_source_daily_limit
    GENERATE_SOURCE_DAILY_LIMIT_DEFAULT
  end

  def generate_source_daily_used_count(now = Time.current)
    generate_source_call_logs.where(called_at: GenerateSourceCallLog.current_day_range(now)).count
  end

  def generate_source_daily_remaining(now = Time.current)
    [ generate_source_daily_limit - generate_source_daily_used_count(now), 0 ].max
  end

  def generate_source_daily_reset_at(now = Time.current)
    GenerateSourceCallLog.next_reset_time(now)
  end

  validates :provider, presence: true, length: { maximum: 255 }
  validates :uid, presence: true, uniqueness: true
  validates :uid, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true
  validates :email, length: { maximum: 255 }
  validates :nickname, presence: true, length: { maximum: 255 }

  def initialize(attributes = {})
    super
    self.nickname = self.name if name.present? && !nickname.present?
  end


  def add_saved_sangakus(sangaku)
    saved_sangakus << sangaku
  end

  def dedicated_sangakus_with_shrine
    @dedicated_sangakus_with_shrine ||= sangakus.where.not(shrine_id: nil).includes(:shrine).to_a
  end
end
