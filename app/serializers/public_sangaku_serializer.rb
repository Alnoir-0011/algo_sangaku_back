class PublicSangakuSerializer
  include JSONAPI::Serializer

  set_type :sangaku
  # description / difficulty は Sangaku から sangakuable へ delegate されている（issue #278）
  attributes :title, :description, :difficulty
  attribute :inputs do |sangaku|
    inputs = sangaku.sangakuable.fixed_inputs
    inputs.map { |input| { id: input.id, content: input.content } }
  end
  attribute :author_name do |sangaku|
    sangaku.user.nickname
  end

  attribute :shrine_name do |sangaku|
    sangaku.shrine&.name
  end

  belongs_to :user
  belongs_to :shrine
end
