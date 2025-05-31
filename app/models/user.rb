class User < ApplicationRecord
  has_many :sangakus

  validates :provider, presence: true, length: { maximum: 255 }
  validates :uid, presence: true, uniqueness: true
  validates :uid, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true
  validates :email, length: { maximum: 255 }
  validates :nickname, presence: true, length: { maximum: 255 }

  def initialize_nickname
    self.nickname = self.name
  end
end
