class UserSangakuSave < ApplicationRecord
  belongs_to :user
  belongs_to :sangaku

  validates :sangaku_id, uniqueness: { scope: :user_id }
  # validate :sangaku_not_already_answered
  #
  # private
  #
  # def sangaku_not_already_answered
  #   if Answer.exists?(user_id: user_id, sangaku_id: sangaku_id)
  #     errors.add(:sangaku_id, "はすでに解答済みのため保存できません")
  #   end
  # end
end
