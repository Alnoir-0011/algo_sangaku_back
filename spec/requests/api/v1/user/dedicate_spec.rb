require 'rails_helper'

RSpec.describe "Api::V1::User::Sangakus::Dedicate", type: :request do
  describe "POST /dedicate" do
    let!(:user) { create(:user) }
    let!(:sangaku) { create(:sangaku, user:, shrine: nil) }
    let!(:shrine) { create(:shrine) }
    let(:params) { {}.to_json }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { post api_v1_user_sangaku_dedicate_path(sangaku.id), headers: headers, params: params }

    context "with access_token" do
      let(:params) { { shrine_id: shrine.id, lat: 35.70204829610801, lng: 139.76789333814216  }.to_json }

      it "return sangaku in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(shrine.sangakus, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end
    end

    context "without access_token", openapi: false do
      let(:params) { { shrine_id: shrine.id, lat: 35.70204829610801, lng: 139.76789333814216 }.to_json }

      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end

    context "with a nonexistent sangaku_id", openapi: false do
      let(:http_request) { post api_v1_user_sangaku_dedicate_path(sangaku.id + 1_000_000), headers: headers, params: params }
      let(:params) { { shrine_id: shrine.id, lat: 35.70204829610801, lng: 139.76789333814216 }.to_json }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with another user's sangaku_id", openapi: false do
      let!(:another_user) { create(:user, nickname: "another") }
      let!(:another_sangaku) { create(:sangaku, user: another_user, shrine: nil) }
      let(:http_request) { post api_v1_user_sangaku_dedicate_path(another_sangaku.id), headers: headers, params: params }
      let(:params) { { shrine_id: shrine.id, lat: 35.70204829610801, lng: 139.76789333814216 }.to_json }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a nonexistent shrine_id", openapi: false do
      let(:params) { { shrine_id: shrine.id + 1_000_000, lat: 35.70204829610801, lng: 139.76789333814216 }.to_json }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "when the distance exceeds the default threshold", openapi: false do
      let(:params) { { shrine_id: shrine.id, lat: 35.71, lng: 139.76789333814216 }.to_json }

      it "return 400 and does not dedicate the sangaku" do
        authenticate_stub(user)

        expect {
          http_request
        }.not_to change(shrine.sangakus, :count)
        expect(response).to have_http_status(400)
      end
    end

    context "when the sangaku already has a shrine", openapi: false do
      let!(:sangaku) { create(:sangaku, user:, shrine: create(:shrine)) }
      let(:params) { { shrine_id: shrine.id, lat: 35.70204829610801, lng: 139.76789333814216 }.to_json }

      it "return 400 and does not change the sangaku's shrine" do
        authenticate_stub(user)

        original_shrine_id = sangaku.shrine_id

        http_request

        expect(response).to have_http_status(400)
        expect(sangaku.reload.shrine_id).to eq original_shrine_id
      end
    end
  end
end
