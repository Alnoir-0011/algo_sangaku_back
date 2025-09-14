require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "Api::V1::Shrines", type: :request do
  describe "GET /shrines" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:shrine_attributes) { attributes_for(:shrine) }
    let(:dummy_body) { { "places" => [
      { "id" => shrine_attributes[:place_id],
        "formattedAddress" => shrine_attributes[:address],
        "location" => { "latitude" => shrine_attributes[:latitude], "longitude" => shrine_attributes[:longitude] },
        "displayName" => { "text" => shrine_attributes[:name], "language" => "ja" } }
    ] }.to_json }

    before do
      # placeApiのモック
      stub_request(:post, "https://places.googleapis.com/v1/places:searchText")
      .to_return(status: 200, body: dummy_body, headers: {})
    end

    describe "Map" do
      let(:params) { { "searchType" => "Map", "lowLat" => "35.4", "highLat" => "35.5", "lowLng" => "135.1", "highLng" => "135.2" } }
      let(:http_request) { get api_v1_shrines_path, params: params, headers: headers }

      context "shrines not created" do
        it "return shrines in json format" do
          expect { http_request }.to change(Shrine, :count).by(1)
          expect(response).to have_http_status(:ok)
        end
      end

      context "shrines already created" do
        let!(:shrine) { create(:shrine, place_id: shrine_attributes[:place_id]) }

        it "shrines does not create" do
          expect { http_request }.to change(Shrine, :count).by(0)
          expect(response).to have_http_status(:ok)
        end
      end

      context "without params", openapi: false do
        let(:params) { { "searchType" => "Map" } }

        it "render 400" do
          http_request

          expect(response).to have_http_status(400)
          expect(body['message']).to eq('Bad Request')
          expect(body['errors'].size).to eq(1)
        end
      end
    end

    describe "List" do
      let(:params) { { "searchType" => "List", "lat" => "35.4", "lng" => "135.2" } }
      let(:http_request) { get api_v1_shrines_path, params: params, headers: headers }

      context "shrines not created" do
        it "return shrines in json format" do
          expect { http_request }.to change(Shrine, :count).by(1)
          expect(response).to have_http_status(:ok)
        end
      end

      context "shrines already created" do
        let!(:shrine) { create(:shrine, place_id: shrine_attributes[:place_id]) }

        it "shrines does not create" do
          expect { http_request }.to change(Shrine, :count).by(0)
          expect(response).to have_http_status(:ok)
        end
      end

      context "without params", openapi: false do
        let(:params) { { "searchType" => "List" } }

        it "return 400" do
          http_request

          expect(response).to have_http_status(400)
          expect(body['message']).to eq('Bad Request')
          expect(body['errors'].size).to eq(1)
        end
      end
    end
  end

  describe "GET /shrines/[:id]" do
    let!(:shrine) { create(:shrine) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

    context "with shrine id" do
      let(:http_request) { get api_v1_shrine_path(shrine.id), headers: }
      it "return in json format" do
        http_request

        expect(response).to have_http_status(200)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["name"]).to eq shrine.name
      end
    end
  end
end
