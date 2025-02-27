class User < ApplicationRecord
  validates :provider, presence: true, length: { maximum: 255 }
  validates :uid, presence: true, uniqueness: true
  validates :uid, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, length: { maximum: 255 }
  validates :nickname, presence: true, length: { maximum: 255 }
end
