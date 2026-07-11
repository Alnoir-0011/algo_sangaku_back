module PlaceApi
  extend ActiveSupport::Concern

  GOOGLE_PLACES_SEARCH_TEXT_URI = "https://places.googleapis.com/v1/places:searchText"

  class_methods do
    def text_search_by_location_restriction(low_lat, high_lat, low_lng, high_lng)
      return nil unless low_lat && high_lat && low_lng && high_lng

      params = {
        "textQuery" => "神社 -寺",
        "languageCode" => "JA",
        "pageSize" => "10",
        "locationRestriction" => {
          "rectangle" => {
            "low" => {
              "latitude" => low_lat,
              "longitude" => low_lng
            },
            "high" => {
              "latitude" => high_lat,
              "longitude" => high_lng
            }
          }
        },
        "regionCode" => "JP",
        "rankPreference" => "DISTANCE"
      }

      perform_search_text_request(params)
    end

    def text_search_by_location_bias(lat, lng)
      return nil unless lat && lng

      params = {
        "textQuery" => "神社 -寺",
        "languageCode" => "JA",
        "pageSize" => "20",
        "locationBias" => {
          "circle" => {
            "center" => {
              "latitude" => lat,
              "longitude" => lng
            },
            "radius" => "1000"
          }
        },
        "regionCode" => "JP",
        "rankPreference" => "DISTANCE"
      }

      perform_search_text_request(params)
    end

    private

    def perform_search_text_request(params)
      uri = URI.parse(GOOGLE_PLACES_SEARCH_TEXT_URI)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme === "https"

      headers = {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => ENV["GOOGLE_MAP_API_KEY"],
        "X-Goog-Fieldmask" => "places.displayName,places.id,places.formattedAddress,places.location"
      }

      req = Net::HTTP::Post.new(uri.path)
      req.body = params.to_json
      req.initialize_http_header(headers)
      response = http.request(req)

      case response
      when Net::HTTPOK
        data = JSON.parse(response.body)
        data["places"]
      else
        raise PlaceApiRequestFailedError, response.code
      end
    end
  end
end
