require 'rails_helper'

RSpec.describe "Api::V1::User::Answers", type: :request do
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

    context "when all answer_results have error status", openapi: false do
      before { answer.answer_results.update_all(status: "error") }

      it "returns incorrect status instead of correct" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["status"]).to eq "incorrect"
      end
    end
  end
end
