class UserSangakuSaveSerializer
  include JSONAPI::Serializer
  belongs_to :user
  belongs_to :sangaku
end
