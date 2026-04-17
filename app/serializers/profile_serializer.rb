class ProfileSerializer
  include JSONAPI::Serializer

  set_type :profile

  attributes :nickname

  attribute :created_at do |user|
    user.created_at
  end

  attribute :sangaku_count do |user|
    user.sangakus.count
  end

  attribute :dedicated_sangaku_count do |user|
    user.dedicated_sangakus_with_shrine.length
  end

  attribute :answer_count do |user|
    user.show_answer_count ? user.answers.count : nil
  end

  attribute :dedicated_sangakus do |user|
    user.dedicated_sangakus_with_shrine.map do |sangaku|
      { id: sangaku.id, title: sangaku.title, shrine_name: sangaku.shrine.name }
    end
  end
end
