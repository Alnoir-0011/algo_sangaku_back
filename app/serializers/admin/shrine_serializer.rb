class Admin::ShrineSerializer
  include JSONAPI::Serializer

  attributes :name, :address, :latitude, :longitude

  attribute :sangaku_count do |shrine|
    shrine.sangakus.count
  end
end
