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
      let!(:another_sangaku) { create(:sangaku, title: "before_dedicate", user:) }
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

    context "search after dedicate" do
      let!(:another_sangaku) { create(:sangaku, title: "before_dedicate", user:) }
      let(:params) { { shrine_id: "any" } }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
      end
    end
  end

  describe "POST /user/sangakus" do
    context "with_accesstoken" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
      let(:params) { { sangaku: attributes_for(:sangaku), fixed_inputs: [ attributes_for(:fixed_input)[:content] ] } }
      let!(:user) { create(:user) }

      it "success to create sangaku" do
        authenticate_stub(user)

        # post api_v1_sangakus_path, headers: headers, params: params.to_json
        expect {
          post api_v1_user_sangakus_path, headers: headers, params: params.to_json
        }.to change(Sangaku, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /user/sangakus/[id]" do
    let(:user) { create(:user) }
    let(:sangaku) { create(:sangaku, user:) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { {} }
    let(:http_request) { get api_v1_user_sangaku_path(sangaku.id), headers:, params: }

    context 'with_accesstoken' do
      it "return sangaku in json formata" do
        authenticate_stub(user)

        http_request

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(body["data"]["id"]).to eq sangaku.id.to_s
      end
    end
  end

  describe "PATCH /user/sangakus/[id]" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { {} }

    context "with_accesstoken" do
      let!(:sangaku) { create(:sangaku, title: "before_changed",  user: user) }
      let(:http_request) { patch api_v1_user_sangaku_path(sangaku.id), headers:, params: }
      let(:params) { { sangaku: attributes_for(:sangaku, title: "changed_title"), fixed_inputs: [ "a" ] }.to_json }

      it "success to update sangaku" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["title"]).to eq "changed_title"
      end
    end

    context "with nonexistent id", openapi: false do
      let(:params) { { sangaku:  attributes_for(:sangaku, title: "changed_title")  }.to_json }
      let(:http_request) { patch api_v1_user_sangaku_path(1000000), headers:, params: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end

    context "with anotheruser's sangaku id", openapi: false do
      let!(:another_user) { create(:user) }
      let!(:another_sangaku) { create(:sangaku, user: another_user) }
      let(:params) { { sangaku:  attributes_for(:sangaku, title: "changed_title") }.to_json }
      let(:http_request) { patch api_v1_user_sangaku_path(another_sangaku.id), headers:, params: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end
  end

  describe "DELETE /sangakus/[id]" do
    let!(:user) { create(:user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { {} }

    context "with with_accesstoken" do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { delete api_v1_user_sangaku_path(sangaku.id), headers: }

      it "return sangaku in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
      end
    end

    context "with nonexistent id", openapi: false do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { delete api_v1_user_sangaku_path(1000000000), headers: }

      it "return 404" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(0)
        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end

    context "with another_user sangaku", openapi: false do
      let!(:another_user) { create(:user, name: "another_user") }
      let!(:another_user_sangaku) { create(:sangaku, user: another_user) }
      let(:http_request) { delete api_v1_user_sangaku_path(another_user_sangaku), headers: }

      it "return 404" do
         authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(0)
        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end
  end
end
