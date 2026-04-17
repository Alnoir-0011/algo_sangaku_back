class SangakuSerializer
  include JSONAPI::Serializer

  set_type :sangaku
  attributes :title, :description, :source, :difficulty
  attribute :inputs do |sangaku|
    inputs = sangaku.fixed_inputs
    inputs.map { |input| { id: input.id, content: input.content } }
  end
  attribute :author_name do |sangaku|
    sangaku.user.nickname
  end

  attribute :shrine_name do |sangaku|
    sangaku.shrine&.name
  end

  # has_many :fixed_inputs
  belongs_to :user
  belongs_to :shrine
end
