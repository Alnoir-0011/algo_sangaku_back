require 'rails_helper'

RSpec.describe "Api::V1::User::SavedSangakus", type: :request, openapi: {
  tags: %w[Api::V1::SangakuSave]
} do
  describe "GET /index" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, user: author, shrine:) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let!(:answered_sangaku) { create(:sangaku, title: "answerd", user: author, shrine:) }
    let!(:answered_sangaku_save_relation) { create(:user_sangaku_save, sangaku: answered_sangaku, user: user) }
    let!(:answer) { create(:answer, user_sangaku_save: answered_sangaku_save_relation) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers: }

    context "with access_token" do
      it 'return unsolved saved sangakus in json format' do
        authenticate_stub(user)
        http_request

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"][0]["attributes"]["author_name"]).to eq author.nickname
      end
    end
  end

  describe "GET /show" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangaku_path(sangaku.id), headers: }

    context "with access_token" do
      it 'return sangaku in json format' do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"]["attributes"]["author_name"]).to eq author.nickname
      end
    end
  end
end
