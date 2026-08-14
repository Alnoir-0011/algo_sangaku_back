require 'rails_helper'

RSpec.describe "Api::V1::Sangakus", type: :request do
  describe "POST /sangakus/[id]/save" do
    let!(:user) { create(:user) }
    let!(:sangaku) { create(:sangaku) }
    let(:http_request) { post api_v1_sangaku_save_path(sangaku.id), headers: }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    context "with access_token" do
      it "return sangaku in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(user.saved_sangakus, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end

      it "does not include the model answer source in the response" do
        authenticate_stub(user)

        http_request

        json = JSON.parse(response.body)
        expect(json["data"]["attributes"]).not_to have_key("source")
        expect(response.body).not_to include(sangaku.source)
      end

      it "returns 409 when the sangaku is already saved" do
        authenticate_stub(user)
        http_request

        expect {
          post api_v1_sangaku_save_path(sangaku.id), headers:
        }.not_to change(user.saved_sangakus, :count)
        expect(response).to have_http_status(:conflict)
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end

    context "with a nonexistent sangaku_id", openapi: false do
      let(:http_request) { post api_v1_sangaku_save_path(sangaku.id + 1_000_000), headers: }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end
  end
end
