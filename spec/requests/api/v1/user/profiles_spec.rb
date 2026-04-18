require 'rails_helper'

RSpec.describe "Api::V1::User::Profiles", type: :request do
  let!(:user) { create(:user) }
  let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

  describe "GET /show" do
    let!(:shrine) { create(:shrine) }
    let!(:dedicated_sangaku) { create(:sangaku, user:, shrine:) }
    let!(:undedicated_sangaku) { create(:sangaku, user:) }
    let(:http_request) { get api_v1_user_profile_path, headers: }

    context "with access_token" do
      it "マイプロフィールを返す" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs["nickname"]).to eq user.nickname
        expect(attrs["email"]).to eq user.email
        expect(attrs["show_answer_count"]).to eq false
        expect(attrs["sangaku_count"]).to eq 2
        expect(attrs["dedicated_sangaku_count"]).to eq 1
        expect(attrs["saved_sangaku_count"]).to eq 0
        expect(attrs["answer_count"]).to eq 0
      end
    end
  end

  describe "PATCH /update" do
    let(:params) { { user: { nickname: "changed_name" } }.to_json }
    let(:http_request) { patch api_v1_user_profile_path, headers:, params: }

    context "with access_token" do
      it "return user in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["nickname"]).to eq "changed_name"
      end
    end

    context "show_answer_count を更新する" do
      let(:params) { { user: { show_answer_count: true } }.to_json }

      it "show_answer_count を true に更新できる" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(user.reload.show_answer_count).to be true
      end
    end
  end
end
