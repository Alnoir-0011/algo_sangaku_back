class FixedInput < ApplicationRecord
  belongs_to :sangaku

  has_many :answer_results

  validates :content, presence: true, length: { maximum: 65_535 }
  validates :content, uniqueness: { scope: :sangaku_id }
end
