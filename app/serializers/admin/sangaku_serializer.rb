class Admin::SangakuSerializer
  include JSONAPI::Serializer

  # description / difficulty は Sangaku から sangakuable へ delegate されている（issue #278）
  attributes :title, :description, :difficulty, :created_at
  attribute :source do |sangaku|
    sangaku.sangakuable.source
  end

  attribute :user_name do |sangaku|
    sangaku.user.nickname
  end

  attribute :shrine_name do |sangaku|
    sangaku.shrine&.name
  end
end
