class Shrine < ApplicationRecord
  include PlaceApi

  has_many :sangakus

  validates :name, presence: true, length: { maximum: 255 }
  validates :address, presence: true, length: { maximum: 255 }
  validates :latitude, numericality: true
  validates :longitude, numericality: true
  validates :place_id, presence: true, uniqueness: true
  validates :place_id, length: { maximum: 255 }

  def self.search_by_bounds(low_lat, high_lat, low_lng, high_lng)
    search_result = self.text_search_by_location_restriction(low_lat, high_lat, low_lng, high_lng)
    filtered_places = self.eleminate_non_shrine(search_result)

    filtered_places.map! do |place|
      {
        name: place["displayName"]["text"],
        address: place["formattedAddress"],
        latitude: place["location"]["latitude"],
        longitude: place["location"]["longitude"],
        place_id: place["id"]
      }
    end

    ActiveRecord::Base.transaction do
      filtered_places.map! do |place|
        shrine = Shrine.find_or_initialize_by(place_id: place[:place_id])

        if shrine.persisted?
          next shrine
        else
          shrine.assign_attributes(place)
          shrine.save!
          next shrine
        end
      end
    end

    filtered_places

  rescue StandardError
    false
  end

  def self.search_by_location(lat, lng)
    search_result = self.text_search_by_location_bias(lat, lng)
    filtered_places = self.eleminate_non_shrine(search_result)

    filtered_places.map! do |place|
      {
        name: place["displayName"]["text"],
        address: place["formattedAddress"],
        latitude: place["location"]["latitude"],
        longitude: place["location"]["longitude"],
        place_id: place["id"]
      }
    end

    ActiveRecord::Base.transaction do
      filtered_places.map! do |place|
        shrine = Shrine.find_or_initialize_by(place_id: place[:place_id])

        if shrine.persisted?
          next shrine
        else
          shrine.assign_attributes(place)
          shrine.save!
          next shrine
        end
      end
    end

    filtered_places

  rescue StandardError
    false
  end

  private

  def self.eleminate_non_shrine(places)
    eleminate_keyword = [ "寺", "手水舎", "社務所", "授与所", "鳥居" ]
    filtered_places = []
    places.map do |place|
      flag = true

      eleminate_keyword.map do |keyword|
        break unless flag

        flag = false if place["displayName"]["text"].include?(keyword)
      end

      if flag || place["displayName"]["text"].include?("社") && place["displayName"]["text"].include?("寺")
        filtered_places << place
      end
    end

    filtered_places
  end
end
