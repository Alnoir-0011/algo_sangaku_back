class User < ApplicationRecord
  has_many :sangakus, dependent: :destroy
  has_many :api_keys
  has_many :user_sangaku_saves, dependent: :destroy, class_name: "UserSangakuSave"
  has_many :saved_sangakus, through: :user_sangaku_saves, source: :sangaku
  has_many :answers, through: :user_sangaku_saves
  has_many :answer_results, through: :answers

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
end
