class Admin::SangakuSerializer
  include JSONAPI::Serializer

  attributes :title, :difficulty, :created_at

  attribute :user_name do |sangaku|
    sangaku.user.nickname
  end

  attribute :shrine_name do |sangaku|
    sangaku.shrine&.name
  end
end
