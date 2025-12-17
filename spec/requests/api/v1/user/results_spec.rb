require 'rails_helper'

RSpec.describe "Api::V1::User::Results", type: :request do
  describe "GET /show" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_sangaku_result_path(sangaku.id), headers: headers }
    let!(:user) { create(:user) }
    let!(:another_user) { create(:user, name: "another_user") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, user:, shrine:) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, user: another_user, sangaku:) }
    let!(:answer) { create(:answer, user_sangaku_save:) }

    context "with access_token" do
      it "return result in json format" do
        answer.answer_results.first.update(output: "Hello world\n", status: "correct")
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["user_sangaku_save_count"]).to eq 1
        expect(body["data"]["attributes"]["correct_count"]).to eq 1
        expect(body["data"]["attributes"]["incorrect_count"]).to eq 0
      end
    end
  end
end
