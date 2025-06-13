class SangakuSerializer
  include JSONAPI::Serializer
  set_type :sangaku
  set_id :user_id
  attributes :title, :description, :source, :difficulty
  attribute :inputs do |sangaku|
    inputs = sangaku.fixed_inputs
    inputs.map { |input| { id: input.id, content: input.content } }
  end
  # has_many :fixed_inputs
  belongs_to :user
end
