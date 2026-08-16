class Shrine < ApplicationRecord
  include PlaceApi

  has_many :sangakus, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :address, presence: true, length: { maximum: 255 }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :place_id, presence: true, uniqueness: true
  validates :place_id, length: { maximum: 255 }

  def self.search_by_bounds(low_lat, high_lat, low_lng, high_lng)
    search_result = self.text_search_by_location_restriction(low_lat, high_lat, low_lng, high_lng)
    return false if search_result.nil?

    persist_places(eleminate_non_shrine(search_result))
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  def self.search_by_location(lat, lng)
    search_result = self.text_search_by_location_bias(lat, lng)
    return false if search_result.nil?

    persist_places(eleminate_non_shrine(search_result))
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  def self.persist_places(filtered_places)
    place_attrs = filtered_places.map do |place|
      {
        name: place.dig("displayName", "text"),
        address: place["formattedAddress"],
        latitude: place.dig("location", "latitude"),
        longitude: place.dig("location", "longitude"),
        place_id: place["id"]
      }
    end

    existing = Shrine.where(place_id: place_attrs.map { |a| a[:place_id] }).index_by(&:place_id)

    place_attrs.filter_map do |attrs|
      shrine = existing[attrs[:place_id]] || Shrine.new(attrs)
      next shrine if shrine.persisted?

      shrine if shrine.save
    end
  end

  def self.eleminate_non_shrine(places)
    sub_location_keywords = [ "手水舎", "社務所", "授与所", "鳥居" ]
    excluded_types = [ "buddhist_temple" ]

    places.select do |place|
      name = place.dig("displayName", "text").to_s
      next false if name.blank?
      next false if sub_location_keywords.any? { |kw| name.include?(kw) }

      types = Array(place["types"]) + [ place["primaryType"] ].compact
      next false if (types & excluded_types).any?

      !name.include?("寺") || name.include?("社")
    end
  end

  private_class_method :persist_places, :eleminate_non_shrine
end
