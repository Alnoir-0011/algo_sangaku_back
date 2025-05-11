class ShrineSerializer
  include JSONAPI::Serializer
  attributes :name, :address, :latitude, :longitude, :place_id
end
