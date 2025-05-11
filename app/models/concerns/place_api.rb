module PlaceApi
  extend ActiveSupport::Concern

  class_methods do
    def text_search_by_location_restriction(low_lat, high_lat, low_lng, high_lng)
      return nil unless low_lat && high_lat && low_lng && high_lng

      api_key = ENV["GOOGLE_MAP_API_KEY"]
      api_uri = "https://places.googleapis.com/v1/places:searchText"

      uri = URI.parse(api_uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme === "https"

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

      headers = {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => api_key,
        "X-Goog-Fieldmask" => "places.displayName,places.id,places.formattedAddress,places.location"
      }

      req = Net::HTTP::Post.new(uri.path)
      req.body = params.to_json
      req.initialize_http_header(headers)
      response = http.request(req)

      case response
      when Net::HTTPOK
        data= JSON.parse(response.body)
        # p data
        data["places"]
      else
        # p response.code
        # p JSON.parse(response.body)
        nil
      end
    end


    def text_search_by_location_bias(lat, lng)
      return nil unless lat && lng

      api_key = ENV["GOOGLE_MAP_API_KEY"]
      api_uri = "https://places.googleapis.com/v1/places:searchText"

      uri = URI.parse(api_uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme === "https"

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

      headers = {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => api_key,
        "X-Goog-Fieldmask" => "places.displayName,places.id,places.formattedAddress,places.location"
      }

      req = Net::HTTP::Post.new(uri.path)
      # p req.body = params.to_json
      req.initialize_http_header(headers)
      response = http.request(req)

      case response
      when Net::HTTPOK
        data= JSON.parse(response.body)
        # p data
        data["places"]
      else
        # p response.code
        # p JSON.parse(response.body)
        nil
      end
    end

    def find_or_getdetals_by(ids)
      api_uri = "https://places.googleapis.com/v1/places/"
      api_key = ENV["GOOGLE_MAP_API_KEY"]

      saved_shrines = self.where(place_id: ids)
      saved_ids = saved_shrines.map { |shrine| shrine.place_id }

      shrines = ids.map do |id|
        next saved_shrines.select { |shrine| shrine.place_id == id }[0] if saved_ids.include?(id)

        uri = URI.parse(api_uri + id)
        params = {
          fields: %w[id displayName formattedAddress location].join(","),
          key: api_key,
          languageCode: "JA"
        }

        uri.query = URI.encode_www_form(params)

        res = Net::HTTP.get_response(uri)

        if res.class == Net::HTTPOK
          body = JSON.parse(res.body)

          shrine = Shrine.new(name: body["displayName"]["text"],
            address: body["formattedAddress"],
            latitude: body["location"]["latitude"],
            longitude: body["location"]["longitude"],
            place_id: body["id"]
          )

          shrine.save!
          shrine
        else
          nil
        end
      end
      shrines
    end
  end
end
