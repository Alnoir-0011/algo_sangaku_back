class FixedInputSerializer
  include JSONAPI::Serializer
  set_type :fixed_input
  set_id :sangaku_id
  attributes :content
  belongs_to :sangaku
end
