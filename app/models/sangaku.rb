class Sangaku < ApplicationRecord
  belongs_to :user
  belongs_to :shrine, optional: true

  has_many :fixed_inputs

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 65_535 }
  validates :source, presence: true, length: { maximum: 65_535 }

  enum :difficulty,
        { easy: 0, nomal: 10, difficult: 20, very_difficult: 30 },
        prefix: true
end
