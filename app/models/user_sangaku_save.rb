class UserSangakuSave < ApplicationRecord
  belongs_to :user
  belongs_to :sangaku

  has_one :answer, dependent: :destroy

  validates :sangaku_id, uniqueness: { scope: :user_id }

  scope :unanswered, -> { left_joins(:answer).where(answers: { id: nil }) }
end
