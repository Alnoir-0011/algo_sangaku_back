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

  private

  def self.persist_places(filtered_places)
    place_attrs = filtered_places.map do |place|
      {
        name: place["displayName"]["text"],
        address: place["formattedAddress"],
        latitude: place["location"]["latitude"],
        longitude: place["location"]["longitude"],
        place_id: place["id"]
      }
    end

    existing = Shrine.where(place_id: place_attrs.map { |a| a[:place_id] }).index_by(&:place_id)

    ActiveRecord::Base.transaction do
      place_attrs.map do |attrs|
        shrine = existing[attrs[:place_id]] || Shrine.new(attrs)
        shrine.save! unless shrine.persisted?
        shrine
      end
    end
  end

  def self.eleminate_non_shrine(places)
    eliminate_keywords = [ "寺", "手水舎", "社務所", "授与所", "鳥居" ]
    places.select do |place|
      name = place["displayName"]["text"]
      has_no_keyword = eliminate_keywords.none? { |kw| name.include?(kw) }
      has_shrine_and_temple = name.include?("社") && name.include?("寺")
      has_no_keyword || has_shrine_and_temple
    end
  end
end
