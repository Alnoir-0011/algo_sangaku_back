require 'rails_helper'

RSpec.describe "Api::V1::User::Answers", type: :request do
  describe "POST /create" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, shrine:, user: author) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, user:, sangaku:) }
    let(:params) { {} }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { post api_v1_user_sangaku_answers_path(sangaku.id), headers:, params: }

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
  end

  describe "GET /show" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, shrine:, user: author) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, user:, sangaku:) }
    let!(:answer) { create(:answer, user_sangaku_save:) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_answer_path(answer.id), headers: }

    context "with access_token" do
      it "return answer in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["source"]).to eq answer.source
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response.body).to eq("HTTP Token: Access denied.\n")
        expect(response).to have_http_status(401)
      end
    end
  end
end
