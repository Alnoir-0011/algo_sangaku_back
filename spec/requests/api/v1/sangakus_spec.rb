require 'rails_helper'

RSpec.describe "Api::V1::Sangakus", type: :request do
  describe "GET /sangakus/[id]" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { {} }

    context "with_accesstoken" do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "return sangakus in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["title"]).to eq sangaku.title
      end
    end

    context "with nonexistent id", openapi: false do
      let(:http_request) { get api_v1_sangaku_path(1000000) }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
      expect(response).not_to be_successful
      end
    end
  end
end
