require 'rails_helper'
require 'webmock/rspec'

RSpec.describe PlaceApi, type: :model do
  let(:search_text_uri) { "https://places.googleapis.com/v1/places:searchText" }
  let(:dummy_places) do
    [
      {
        "id" => "dummy_place_id",
        "formattedAddress" => "dummy address",
        "location" => { "latitude" => 35.4, "longitude" => 135.1 },
        "displayName" => { "text" => "dummy神社", "language" => "ja" }
      }
    ]
  end
  let(:dummy_body) { { "places" => dummy_places }.to_json }

  describe ".text_search_by_location_restriction" do
    context "when required arguments are missing" do
      it "returns nil when low_lat is nil" do
        # Arrange
        # low_lat が nil のケース

        # Act
        result = Shrine.text_search_by_location_restriction(nil, 2, 3, 4)

        # Assert
        expect(result).to be_nil
      end

      it "returns nil when high_lat is nil" do
        # Arrange
        # high_lat が nil のケース

        # Act
        result = Shrine.text_search_by_location_restriction(1, nil, 3, 4)

        # Assert
        expect(result).to be_nil
      end

      it "returns nil when low_lng is nil" do
        # Arrange
        # low_lng が nil のケース

        # Act
        result = Shrine.text_search_by_location_restriction(1, 2, nil, 4)

        # Assert
        expect(result).to be_nil
      end

      it "returns nil when high_lng is nil" do
        # Arrange
        # high_lng が nil のケース

        # Act
        result = Shrine.text_search_by_location_restriction(1, 2, 3, nil)

        # Assert
        expect(result).to be_nil
      end

      it "does not send an HTTP request when arguments are missing" do
        # Arrange
        # 引数不足時に外部APIへリクエストが飛ばないことを確認する

        # Act
        Shrine.text_search_by_location_restriction(nil, 2, 3, 4)

        # Assert
        expect(WebMock).not_to have_requested(:post, search_text_uri)
      end
    end

    context "when Google Places API returns 200 OK" do
      before do
        stub_request(:post, search_text_uri)
          .to_return(status: 200, body: dummy_body, headers: {})
      end

      it "returns the places array from the response body" do
        # Arrange
        # 200 OK 応答が dummy_body を返すようスタブ済み

        # Act
        result = Shrine.text_search_by_location_restriction(35.4, 35.5, 135.1, 135.2)

        # Assert
        expect(result).to eq(dummy_places)
      end
    end

    context "when Google Places API returns a non-200 response" do
      it "raises PlaceApiRequestFailedError with status_code 500 when the API responds with 500" do
        # Arrange
        stub_request(:post, search_text_uri)
          .to_return(status: 500, body: { error: "Internal Server Error" }.to_json, headers: {})

        # Act & Assert
        expect {
          Shrine.text_search_by_location_restriction(35.4, 35.5, 135.1, 135.2)
        }.to raise_error(PlaceApiRequestFailedError) { |error| expect(error.status_code).to eq("500") }
      end

      it "raises PlaceApiRequestFailedError with status_code 429 when the API responds with 429" do
        # Arrange
        stub_request(:post, search_text_uri)
          .to_return(status: 429, body: { error: "Too Many Requests" }.to_json, headers: {})

        # Act & Assert
        expect {
          Shrine.text_search_by_location_restriction(35.4, 35.5, 135.1, 135.2)
        }.to raise_error(PlaceApiRequestFailedError) { |error| expect(error.status_code).to eq("429") }
      end
    end
  end

  describe ".text_search_by_location_bias" do
    context "when required arguments are missing" do
      it "returns nil when lat is nil" do
        # Arrange
        # lat が nil のケース

        # Act
        result = Shrine.text_search_by_location_bias(nil, 135.1)

        # Assert
        expect(result).to be_nil
      end

      it "returns nil when lng is nil" do
        # Arrange
        # lng が nil のケース

        # Act
        result = Shrine.text_search_by_location_bias(35.4, nil)

        # Assert
        expect(result).to be_nil
      end

      it "does not send an HTTP request when arguments are missing" do
        # Arrange
        # 引数不足時に外部APIへリクエストが飛ばないことを確認する

        # Act
        Shrine.text_search_by_location_bias(nil, 135.1)

        # Assert
        expect(WebMock).not_to have_requested(:post, search_text_uri)
      end
    end

    context "when Google Places API returns 200 OK" do
      before do
        stub_request(:post, search_text_uri)
          .to_return(status: 200, body: dummy_body, headers: {})
      end

      it "returns the places array from the response body" do
        # Arrange
        # 200 OK 応答が dummy_body を返すようスタブ済み

        # Act
        result = Shrine.text_search_by_location_bias(35.4, 135.1)

        # Assert
        expect(result).to eq(dummy_places)
      end
    end

    context "when Google Places API returns a non-200 response" do
      it "raises PlaceApiRequestFailedError with status_code 500 when the API responds with 500" do
        # Arrange
        stub_request(:post, search_text_uri)
          .to_return(status: 500, body: { error: "Internal Server Error" }.to_json, headers: {})

        # Act & Assert
        expect {
          Shrine.text_search_by_location_bias(35.4, 135.1)
        }.to raise_error(PlaceApiRequestFailedError) { |error| expect(error.status_code).to eq("500") }
      end

      it "raises PlaceApiRequestFailedError with status_code 429 when the API responds with 429" do
        # Arrange
        stub_request(:post, search_text_uri)
          .to_return(status: 429, body: { error: "Too Many Requests" }.to_json, headers: {})

        # Act & Assert
        expect {
          Shrine.text_search_by_location_bias(35.4, 135.1)
        }.to raise_error(PlaceApiRequestFailedError) { |error| expect(error.status_code).to eq("429") }
      end
    end
  end
end
