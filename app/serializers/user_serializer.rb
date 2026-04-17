class UserSerializer
  include JSONAPI::Serializer
  attributes :provider, :uid, :name, :email, :nickname, :show_answer_count

  attribute :sangaku_count do |user|
    user.sangakus.count
  end

  attribute :dedicated_sangaku_count do |user|
    user.sangakus.where.not(shrine_id: nil).count
  end

  attribute :saved_sangaku_count do |user|
    user.saved_sangakus.count
  end

  attribute :answer_count do |user|
    user.answers.count
  end
end
