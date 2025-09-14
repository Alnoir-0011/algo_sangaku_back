
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
        expect(body["data"]["attributes"]["output"]).to eq "Hello world\n"
        expect(body["data"]["attributes"]["status"]).to eq "correct"
      end
    end
  end
end
