class Admin::UserSerializer
  include JSONAPI::Serializer

  attributes :name, :email, :nickname, :role, :created_at

  attribute :sangaku_count do |user|
    user.sangakus.count
  end

  attribute :answer_count do |user|
    user.answers.count
  end
end
