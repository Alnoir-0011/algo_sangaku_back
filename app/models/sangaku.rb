class Sangaku < ApplicationRecord
  belongs_to :user
  belongs_to :shrine, optional: true

  has_many :fixed_inputs, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 65_535 }
  validates :source, presence: true, length: { maximum: 65_535 }

  validate :fixed_inputs_uniqueness

  enum :difficulty,
        { easy: 0, nomal: 10, difficult: 20, very_difficult: 30 },
        prefix: true

  def save_with_inputs(inputs)
    inputs_invalid = inputs.map(&:invalid?).any?(true)

    return false if invalid? || inputs_invalid

    ActiveRecord::Base.transaction do
      save!
      inputs.map(&:save!)
    end
    true
  rescue StandardError
    false
  end

  private

  def fixed_inputs_uniqueness
    content_ary = fixed_inputs.map(&:content)

    if content_ary.uniq.length != content_ary.length
      errors.add(:base, "固定入力が重複しています")
    end
  end
end
