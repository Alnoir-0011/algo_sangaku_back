require 'rails_helper'

RSpec.describe "Api::V1::User::SavedSangakus::Answer", type: :request do
  describe "POST /create" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, shrine:, user: author) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, user:, sangaku:) }
    let(:params) { {} }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { post api_v1_user_saved_sangaku_answer_path(sangaku.id), headers:, params: }

    context "with access_token" do
      let(:params) { { answer: { source: "puts 'Hello wourld'" } }.to_json }

      it "return answer in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Answer, :count).by(1)
            .and change(AnswerResult, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["source"]).to eq "puts 'Hello wourld'"
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response.body).to eq("HTTP Token: Access denied.\n")
        expect(response).to have_http_status(401)
      end
    end

    context "without source", openapi: false do
      let(:params) { { answer: { source: "" } }.to_json }

      it "return 400 errors" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Answer, :count).by(0)
        expect(response).to have_http_status(400)
        expect(body["errors"]).to eq [ [ "source", [ "を入力してください" ] ] ]
      end
    end

    context "when the sangaku_save already has an answer", openapi: false do
      let!(:existing_answer) { create(:answer, user_sangaku_save:) }
      let(:params) { { answer: { source: "puts 'new answer'" } }.to_json }

      it "returns 409 and does not delete the existing answer" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Answer, :count).by(0)

        expect(response).to have_http_status(409)
        expect(Answer.exists?(existing_answer.id)).to be true
      end
    end

    context "with an unwrapped body (same shape as the front client sends)", openapi: false do
      let(:params) { { source: "puts 'unwrapped body'" }.to_json }

      it "still wraps the params under :answer and creates the answer" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Answer, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["source"]).to eq "puts 'unwrapped body'"
      end
    end

    context "when the current_user has not saved the sangaku", openapi: false do
      let!(:unsaved_sangaku) { create(:sangaku, shrine:, user: author) }
      let(:params) { { answer: { source: "puts 'Hello wourld'" } }.to_json }
      let(:http_request) { post api_v1_user_saved_sangaku_answer_path(unsaved_sangaku.id), headers:, params: }

      it "returns 404 and does not create an answer" do
        authenticate_stub(user)

        expect {
          http_request
        }.not_to change(Answer, :count)

        expect(response).to have_http_status(404)
      end
    end
  end

  describe "GET /show" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let!(:answer) { create(:answer, user_sangaku_save: sangaku_save_relation) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangaku_answer_path(sangaku.id), headers: }

    context "with access_token" do
      it "return answer in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body['data']['attributes']['source']).to eq answer.source
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end

    context "when the sangaku has not been answered yet", openapi: false do
      let!(:unanswered_sangaku) { create(:sangaku, user: author) }
      let!(:unanswered_sangaku_save_relation) { create(:user_sangaku_save, sangaku: unanswered_sangaku, user: user) }
      let(:http_request) { get api_v1_user_saved_sangaku_answer_path(unanswered_sangaku.id), headers: }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "when another user has answered the same sangaku but current_user has not", openapi: false do
      let!(:other_user) { create(:user) }
      let!(:shared_sangaku) { create(:sangaku, user: author) }
      let!(:current_user_save) { create(:user_sangaku_save, sangaku: shared_sangaku, user: user) }
      let!(:other_user_save) { create(:user_sangaku_save, sangaku: shared_sangaku, user: other_user) }
      let!(:other_answer) { create(:answer, user_sangaku_save: other_user_save) }
      let(:http_request) { get api_v1_user_saved_sangaku_answer_path(shared_sangaku.id), headers: }

      it "returns 404 without leaking the other user's answer" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "when the current_user has not saved the sangaku", openapi: false do
      let!(:unsaved_sangaku) { create(:sangaku, user: author) }
      let(:http_request) { get api_v1_user_saved_sangaku_answer_path(unsaved_sangaku.id), headers: }

      it "returns 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end
  end
end
