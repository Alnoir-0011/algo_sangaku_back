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

    context "with a reorder sangaku" do
      let!(:sangaku) { create(:sangaku, :reorder, shrine:, user: author) }
      let(:correct_block_ids) do
        sangaku.sangakuable.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)
      end

      context "with correct block_ids" do
        let(:params) { { answer: { block_ids: correct_block_ids } }.to_json }

        it "returns 200 with a correct status and does not create an answer_result" do
          authenticate_stub(user)

          expect {
            http_request
          }.to change(Answer, :count).by(1)
              .and change(ReorderAnswer, :count).by(1)
              .and change(AnswerResult, :count).by(0)

          expect(response).to have_http_status(:ok)
          expect(body["data"]["attributes"]["status"]).to eq "correct"
          expect(body["data"]["attributes"]["source"]).to be_nil
        end
      end

      context "with block_ids that reference a non-existent code_block" do
        let(:params) { { answer: { block_ids: [ correct_block_ids.first, correct_block_ids.last + 1_000_000 ] } }.to_json }

        it "returns 200 with an incorrect status and still saves the answer" do
          authenticate_stub(user)

          expect {
            http_request
          }.to change(Answer, :count).by(1)
              .and change(ReorderAnswer, :count).by(1)
              .and change(AnswerResult, :count).by(0)

          expect(response).to have_http_status(:ok)
          expect(body["data"]["attributes"]["status"]).to eq "incorrect"
        end
      end

      context "when the sangaku_save already has an answer", openapi: false do
        let!(:existing_answer) { create(:answer, :reorder, user_sangaku_save:) }
        let(:params) { { answer: { block_ids: correct_block_ids } }.to_json }

        it "returns 409 and does not delete the existing answer" do
          authenticate_stub(user)

          expect {
            http_request
          }.to change(Answer, :count).by(0)
              .and change(ReorderAnswer, :count).by(0)

          expect(response).to have_http_status(409)
          expect(Answer.exists?(existing_answer.id)).to be true
        end
      end

      context "when the current_user has not saved the sangaku", openapi: false do
        let!(:unsaved_sangaku) { create(:sangaku, :reorder, shrine:, user: author) }
        let(:unsaved_block_ids) do
          unsaved_sangaku.sangakuable.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)
        end
        let(:params) { { answer: { block_ids: unsaved_block_ids } }.to_json }
        let(:http_request) { post api_v1_user_saved_sangaku_answer_path(unsaved_sangaku.id), headers:, params: }

        it "returns 404 and does not create an answer" do
          authenticate_stub(user)

          expect {
            http_request
          }.to change(Answer, :count).by(0)
              .and change(ReorderAnswer, :count).by(0)

          expect(response).to have_http_status(404)
        end
      end

      context "with a malformed block_ids", openapi: false do
        context "when block_ids is missing" do
          let(:params) { { answer: {} }.to_json }

          it "returns 400 and does not create an answer" do
            authenticate_stub(user)

            expect {
              http_request
            }.to change(Answer, :count).by(0)
                .and change(ReorderAnswer, :count).by(0)

            expect(response).to have_http_status(400)
          end
        end

        context "when block_ids is not an array" do
          let(:params) { { answer: { block_ids: "invalid" } }.to_json }

          it "returns 400 and does not create an answer" do
            authenticate_stub(user)

            expect {
              http_request
            }.to change(Answer, :count).by(0)
                .and change(ReorderAnswer, :count).by(0)

            expect(response).to have_http_status(400)
          end
        end

        context "when block_ids contains non-integer elements" do
          let(:params) { { answer: { block_ids: [ "a", "b" ] } }.to_json }

          it "returns 400 and does not create an answer" do
            authenticate_stub(user)

            expect {
              http_request
            }.to change(Answer, :count).by(0)
                .and change(ReorderAnswer, :count).by(0)

            expect(response).to have_http_status(400)
          end
        end

        context "when block_ids is empty" do
          let(:params) { { answer: { block_ids: [] } }.to_json }

          it "returns 400 and does not create an answer" do
            authenticate_stub(user)

            expect {
              http_request
            }.to change(Answer, :count).by(0)
                .and change(ReorderAnswer, :count).by(0)

            expect(response).to have_http_status(400)
          end
        end

        context "when block_ids contains duplicate ids" do
          let(:params) { { answer: { block_ids: [ correct_block_ids.first, correct_block_ids.first ] } }.to_json }

          it "returns 400 and does not create an answer" do
            authenticate_stub(user)

            expect {
              http_request
            }.to change(Answer, :count).by(0)
                .and change(ReorderAnswer, :count).by(0)

            expect(response).to have_http_status(400)
          end
        end

        context "when block_ids exceeds ReorderSangaku::MAX_CODE_BLOCKS" do
          let(:params) { { answer: { block_ids: (1..(ReorderSangaku::MAX_CODE_BLOCKS + 1)).to_a } }.to_json }

          it "returns 400 and does not create an answer" do
            authenticate_stub(user)

            expect {
              http_request
            }.to change(Answer, :count).by(0)
                .and change(ReorderAnswer, :count).by(0)

            expect(response).to have_http_status(400)
          end
        end
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

    context "when the sangaku is a reorder format" do
      let!(:sangaku) { create(:sangaku, :reorder, user: author) }
      let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:answer) { create(:answer, :reorder, user_sangaku_save: sangaku_save_relation, result: :correct) }
      let(:http_request) { get api_v1_user_saved_sangaku_answer_path(sangaku.id), headers: }

      it "returns the status without a source and with no answer_results" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["status"]).to eq "correct"
        expect(body["data"]["attributes"]["source"]).to be_nil
        expect(body["data"]["relationships"]["answer_results"]["data"]).to eq []
      end
    end

    context "with a code answer", openapi: false do
      it "returns kind code in the response" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "code"
      end
    end

    context "with a reorder answer", openapi: false do
      let!(:sangaku) { create(:sangaku, :reorder, user: author) }
      let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:answer) { create(:answer, :reorder, user_sangaku_save: sangaku_save_relation, result: :correct) }
      let(:http_request) { get api_v1_user_saved_sangaku_answer_path(sangaku.id), headers: }

      it "returns kind reorder in the response" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "reorder"
      end
    end
  end
end
