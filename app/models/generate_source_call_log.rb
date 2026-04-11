class GenerateSourceCallLog < ApplicationRecord
  belongs_to :user

  validates :called_at, presence: true

  def self.current_day_range(now = Time.current)
    day_start = current_day_start(now)
    day_start...next_reset_time(now)
  end

  def self.next_reset_time(now = Time.current)
    current_day_start(now) + 1.day
  end

  def self.current_day_start(now = Time.current)
    jst_now = now.in_time_zone("Asia/Tokyo")
    boundary_hour = 3

    if jst_now.hour < boundary_hour
      jst_now.beginning_of_day.change(hour: boundary_hour) - 1.day
    else
      jst_now.beginning_of_day.change(hour: boundary_hour)
    end
  end
end
