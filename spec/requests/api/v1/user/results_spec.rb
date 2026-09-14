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
        answer.answerable.answer_results.first.update(output: "Hello world\n", status: "correct")
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["user_sangaku_save_count"]).to eq 1
        expect(body["data"]["attributes"]["correct_count"]).to eq 1
        expect(body["data"]["attributes"]["incorrect_count"]).to eq 0
      end

      it "counts an answer with all-error results as incorrect", openapi: false do
        answer.answerable.answer_results.first.update!(status: "error")
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["correct_count"]).to eq 0
        expect(body["data"]["attributes"]["incorrect_count"]).to eq 1
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end

    context "with a nonexistent sangaku_id", openapi: false do
      let(:http_request) { get api_v1_user_sangaku_result_path(sangaku.id + 1_000_000), headers: headers }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with another user's sangaku_id", openapi: false do
      let(:http_request) { get api_v1_user_sangaku_result_path(sangaku.id), headers: headers }

      it "return 404" do
        authenticate_stub(another_user)

        http_request

        expect(response).to have_http_status(404)
      end
    end
  end

  # 上の describe "GET /show" 内の let! はコード記述形式の算額を前提に組まれているため、
  # 並べ替え形式のデータで検証する際に共有 let! から不要なデータが混入しないよう、
  # 独立した describe として自己完結するデータを組み立てる。
  describe "GET /show (reorder format)" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_sangaku_result_path(sangaku.id), headers: headers }
    let!(:user) { create(:user) }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, :reorder, user:, shrine:) }
    let!(:saved_user_1) { create(:user) }
    let!(:saved_user_2) { create(:user) }
    let!(:saved_user_3) { create(:user) }
    let!(:save_1) { create(:user_sangaku_save, user: saved_user_1, sangaku:) }
    let!(:save_2) { create(:user_sangaku_save, user: saved_user_2, sangaku:) }
    let!(:save_3) { create(:user_sangaku_save, user: saved_user_3, sangaku:) }
    let!(:correct_answer) { create(:answer, :reorder, user_sangaku_save: save_1, result: :correct) }
    let!(:incorrect_answer) { create(:answer, :reorder, user_sangaku_save: save_2, result: :incorrect) }

    context "when the sangaku is a reorder-format one, with 3 saves (1 correct, 1 incorrect, 1 unanswered)", openapi: false do
      it "sums user_sangaku_save_count across saves" do
        authenticate_stub(user)
        http_request

        expect(body["data"]["attributes"]["user_sangaku_save_count"]).to eq 3
      end

      it "counts correct answers for the reorder format" do
        authenticate_stub(user)
        http_request

        expect(body["data"]["attributes"]["correct_count"]).to eq 1
      end

      it "counts incorrect answers for the reorder format" do
        authenticate_stub(user)
        http_request

        expect(body["data"]["attributes"]["incorrect_count"]).to eq 1
      end
    end
  end
end
