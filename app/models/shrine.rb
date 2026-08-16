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
  # persist_places は save（非bang）を使い RecordNotUnique も内部でrescueするため、
  # 通常経路ではここに到達しない。想定外の経路に備えた防御的rescueとして残す。
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

      if shrine.save
        shrine
      else
        Rails.logger.warn("Shrine persist failed: place_id=#{attrs[:place_id]} errors=#{shrine.errors.full_messages.join(', ')}")
        nil
      end
    rescue ActiveRecord::RecordNotUnique
      # 同時リクエストが同じ place_id を先に保存した場合、競合相手の行を採用する
      Shrine.find_by(place_id: attrs[:place_id])
    end
  end

  # 判定の優先順位: ①子ロケーション名（手水舎・社務所等）は「社」「寺」の組み合わせに関わらず常に除外
  # → ②type情報（primaryType/types）による除外 → ③名前ベースの「寺」判定（「社」を含む場合のみ復活）。
  # ①を最優先にしないと「〇〇寺社務所」のような名前が③の判定で誤って復活してしまう。
  def self.eleminate_non_shrine(places)
    sub_location_keywords = [ "手水舎", "社務所", "授与所", "鳥居" ]
    excluded_types = [ "buddhist_temple" ]

    places.select do |place|
      next false unless place.is_a?(Hash)

      name = place.dig("displayName", "text").to_s
      next false if name.blank?
      next false if sub_location_keywords.any? { |kw| name.include?(kw) }

      raw_types = place["types"]
      types = (raw_types.is_a?(Array) ? raw_types : []) + [ place["primaryType"] ].compact
      next false if (types & excluded_types).any?

      !name.include?("寺") || name.include?("社")
    end
  end

  private_class_method :persist_places, :eleminate_non_shrine
end
