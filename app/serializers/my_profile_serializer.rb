class MyProfileSerializer
  include JSONAPI::Serializer

  set_type :my_profile

  attributes :email, :nickname, :show_answer_count

  attribute :created_at do |user|
    user.created_at
  end

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
