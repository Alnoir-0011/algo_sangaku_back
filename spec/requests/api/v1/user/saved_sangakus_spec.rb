require 'rails_helper'

RSpec.describe "Api::V1::User::SavedSangakus", type: :request, openapi: { tags: %w[Api::V1::SangakuSave] } do
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
    let(:params) { { type: "before_answer" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers:, params: }

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

      it "does not include source in response" do
        authenticate_stub(user)
        http_request

        expect(body["data"][0]["attributes"].keys).not_to include("source")
      end
    end
  end

  describe "GET /index with multiple users' answer status" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers:, params: }

    context "when another user has answered the same saved sangaku" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:shrine) { create(:shrine) }
      let!(:sangaku) { create(:sangaku, user: author, shrine:) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }
      let!(:other_answer) { create(:answer, user_sangaku_save: other_save) }

      context "with type=before_answer" do
        let(:params) { { type: "before_answer" } }

        it "includes the sangaku since current_user has not answered it yet" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).to include(sangaku.id.to_s)
        end
      end

      context "with type=answered" do
        let(:params) { { type: "answered" } }

        it "does not include the sangaku since current_user has not answered it" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).not_to include(sangaku.id.to_s)
        end
      end
    end

    context "when current_user has answered but another user has not" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:shrine) { create(:shrine) }
      let!(:sangaku) { create(:sangaku, user: author, shrine:) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:user_answer) { create(:answer, user_sangaku_save: user_save) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }

      context "with type=answered" do
        let(:params) { { type: "answered" } }

        it "includes the sangaku since current_user has answered it" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).to include(sangaku.id.to_s)
        end
      end

      context "with type=before_answer" do
        let(:params) { { type: "before_answer" } }

        it "does not include the sangaku since current_user has already answered it" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).not_to include(sangaku.id.to_s)
        end
      end
    end
  end

  describe "GET /show" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { type: "before_answer" } }
    let(:http_request) { get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: }

    context "with access_token" do
      it 'return sangaku in json format' do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"]["attributes"]["author_name"]).to eq author.nickname
      end

      it "does not include source in response" do
        authenticate_stub(user)
        http_request

        expect(body["data"]["attributes"].keys).not_to include("source")
      end
    end
  end

  describe "GET /show with multiple users' answer status" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { type: "before_answer" } }
    let(:http_request) { get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: }

    context "when another user has answered the same saved sangaku but current_user has not" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:sangaku) { create(:sangaku, user: author) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }
      let!(:other_answer) { create(:answer, user_sangaku_save: other_save) }

      it "returns the sangaku" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["id"]).to eq sangaku.id.to_s
      end
    end

    context "when current_user has already answered the saved sangaku" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:sangaku) { create(:sangaku, user: author) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:user_answer) { create(:answer, user_sangaku_save: user_save) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }

      it "returns not found since current_user has already answered it" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /answer" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let!(:answer) { create(:answer, user_sangaku_save: sangaku_save_relation) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get answer_api_v1_user_saved_sangaku_path(sangaku.id), headers: }

    context "with access_token" do
      it "return answer in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body['data']['attributes']['source']).to eq answer.source
      end
    end
  end
end
