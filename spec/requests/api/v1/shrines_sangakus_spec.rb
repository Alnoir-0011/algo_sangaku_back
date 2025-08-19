require 'rails_helper'

RSpec.describe "Api::V1::ShrinesSangakus", type: :request do
  describe "GET /api/v1/shrine/{id}/sangakus" do
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, title: "test_title", difficulty: "nomal", shrine: shrine) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:params) { {} }
    let(:http_request) { get api_v1_shrine_sangakus_path(shrine.id), headers:, params: }

    context "with access_token" do
      let(:params) { { title: "test_title", difficulty: "nomal" } }
      it "return sangakus in json format" do
        http_request

        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"][0]["id"]).to eq sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
      end
    end
  end
end
