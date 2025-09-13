require 'rails_helper'

RSpec.describe "Api::V1::User::SangakuSaves", type: :request, openapi: {
  tags: %w[Api::V1::SangakuSave]
} do
  describe "GET /index" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_sangaku_saves_path, headers: }

    context "with_access_token" do
      it 'return sangakus in json format' do
        authenticate_stub(user)

        http_request

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"][0]["attributes"]["author_name"]).to eq author.nickname
      end
    end
  end
end
