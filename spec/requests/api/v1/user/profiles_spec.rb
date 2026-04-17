require 'rails_helper'

RSpec.describe "Api::V1::User::Profiles", type: :request do
  describe "PATCH /update" do
    let!(:user) { create(:user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { user: { nickname: "changed_name" } }.to_json }
    let(:http_request) { patch api_v1_user_profile_path, headers:, params: }

    context "with access_token" do
      it "return user in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["nickname"]).to eq "changed_name"
      end

      it "活動サマリーを返す", openapi: false do
        authenticate_stub(user)
        http_request

        attrs = body["data"]["attributes"]
        expect(attrs).to have_key("sangaku_count")
        expect(attrs).to have_key("dedicated_sangaku_count")
        expect(attrs).to have_key("saved_sangaku_count")
        expect(attrs).to have_key("answer_count")
        expect(attrs).to have_key("show_answer_count")
      end
    end

    context "show_answer_count を更新する", openapi: false do
      let(:params) { { user: { show_answer_count: true } }.to_json }

      it "show_answer_count を true に更新できる" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["show_answer_count"]).to be true
        expect(user.reload.show_answer_count).to be true
      end
    end
  end
end
