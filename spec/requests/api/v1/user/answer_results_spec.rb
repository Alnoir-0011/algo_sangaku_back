
require 'rails_helper'

RSpec.describe "Api::V1::User::AnswerResults", type: :request do
  describe "GET /show" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, shrine:, user: author) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, user:, sangaku:) }
    let!(:answer) { create(:answer, user_sangaku_save:) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_answer_result_path(answer.answer_results.first.id), headers: }

    context "with access_token" do
      it "return answer_result in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end

    context "with a nonexistent answer_result id", openapi: false do
      let(:http_request) { get api_v1_user_answer_result_path(answer.answer_results.first.id + 1_000_000), headers: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with another user's answer_result", openapi: false do
      let!(:another_user) { create(:user, nickname: "another") }
      let!(:another_user_sangaku_save) { create(:user_sangaku_save, user: another_user, sangaku:) }
      let!(:another_answer) { create(:answer, user_sangaku_save: another_user_sangaku_save) }
      let(:http_request) { get api_v1_user_answer_result_path(another_answer.answer_results.first.id), headers: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(404)
      end
    end
  end
end
