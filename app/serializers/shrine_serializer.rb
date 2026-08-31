class ShrineSerializer
  include JSONAPI::Serializer
  attributes :name, :address, :latitude, :longitude, :place_id

  attribute :sangaku_count do |shrine, params|
    params[:sangaku_counts][shrine.id] || 0
  end
end
