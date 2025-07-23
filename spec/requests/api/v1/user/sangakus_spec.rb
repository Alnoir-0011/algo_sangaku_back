require 'rails_helper'

RSpec.describe "Api::V1::User::Sangakus", type: :request do
  describe "GET /index" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_sangakus_path, params: params, headers: headers }
    let!(:user) { create(:user) }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, user:, shrine:) }
    let!(:another_user) { create(:user, name: "another_user") }
    let!(:another_user_sangaku) { create(:sangaku, user: another_user) }

    context "with_accesstoken" do
      let(:params) { {} }

      it "return sangakus in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"][0]["id"]).to eq sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
      end
    end

    context "search by title" do
      let(:params) { { title: "another" } }
      let!(:another_sangaku) { create(:sangaku, title: 'another_title', user:) }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq another_sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq another_sangaku.title
      end
    end

    context "search by shrine_id" do
      let!(:another_shrine) { create(:shrine, name: "another_shrine") }
      let!(:another_sangaku) { create(:sangaku, title: "another_shrine", user:, shrine: another_shrine) }
      let(:params) { { shrine_id: another_shrine.id } }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq another_sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq another_sangaku.title
      end
    end

    context "search befoer dedicate" do
      let!(:another_sangaku) { create(:sangaku, title: "after_dedicate", user:) }
      let(:params) { { shrine_id: "" } }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq another_sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq another_sangaku.title
      end
    end
  end
end
