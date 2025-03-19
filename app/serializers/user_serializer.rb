class UserSerializer
  include JSONAPI::Serializer
  attributes :provider, :uid, :name, :email, :nickname
end
