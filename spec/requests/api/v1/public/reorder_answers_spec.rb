require 'rails_helper'

RSpec.describe "Api::V1::Public::ReorderAnswers", type: :request do
  describe "POST /public/reorder_sangakus/[:reorder_sangaku_id]/answer" do
    let!(:shrine) { create(:shrine) }
    let!(:reorder_sangaku) { create(:sangaku, :reorder, shrine: shrine) }
    let(:code_blocks) { reorder_sangaku.sangakuable.code_blocks }
    let(:correct_block_ids) { code_blocks.order(:correct_position).pluck(:id) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:http_request) { post api_v1_public_reorder_sangaku_answer_path(reorder_sangaku.id), headers:, params: }

    context "with correct block_ids" do
      let(:params) { { answer: { block_ids: correct_block_ids } }.to_json }

      it "returns 200" do
        http_request

        expect(response).to have_http_status(200)
      end

      it "returns status correct" do
        http_request

        expect(body["status"]).to eq("correct")
      end

      it "does not create an Answer record" do
        expect { http_request }.not_to change(Answer, :count)
      end

      it "does not create an AnswerResult record" do
        expect { http_request }.not_to change(AnswerResult, :count)
      end
    end

    context "with incorrect block_ids" do
      let(:params) { { answer: { block_ids: correct_block_ids.reverse } }.to_json }

      it "returns 200" do
        http_request

        expect(response).to have_http_status(200)
      end

      it "returns status incorrect" do
        http_request

        expect(body["status"]).to eq("incorrect")
      end

      it "does not create an Answer record" do
        expect { http_request }.not_to change(Answer, :count)
      end

      it "does not create an AnswerResult record" do
        expect { http_request }.not_to change(AnswerResult, :count)
      end
    end

    context "with a non-representative reorder sangaku id", openapi: false do
      let!(:representative_user_sangaku_save) { create(:user_sangaku_save, sangaku: reorder_sangaku) }
      let!(:representative_answer) { create(:answer, :reorder, user_sangaku_save: representative_user_sangaku_save) }
      let!(:non_representative_sangaku) { create(:sangaku, :reorder, shrine: shrine) }
      let(:params) { { answer: { block_ids: [ 1, 2, 3 ] } }.to_json }
      let(:http_request) { post api_v1_public_reorder_sangaku_answer_path(non_representative_sangaku.id), headers:, params: }

      # GET側と同じ理由（id存在有無の推測防止）で404に倒す（issue #359）。
      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a code sangaku id", openapi: false do
      let!(:code_sangaku) { create(:sangaku, shrine: shrine) }
      let(:params) { { answer: { block_ids: [ 1, 2, 3 ] } }.to_json }
      let(:http_request) { post api_v1_public_reorder_sangaku_answer_path(code_sangaku.id), headers:, params: }

      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with invalid block_ids" do
      context "when block_ids is not an array" do
        let(:params) { { answer: { block_ids: "invalid" } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end

      context "when block_ids is empty" do
        let(:params) { { answer: { block_ids: [] } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end

      context "when block_ids exceeds the maximum count" do
        let(:params) { { answer: { block_ids: (1..(ReorderSangaku::MAX_CODE_BLOCKS + 1)).to_a } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end

      context "when block_ids contains duplicated elements" do
        let(:params) { { answer: { block_ids: [ correct_block_ids.first, correct_block_ids.first ] } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end

      context "when block_ids contains non-integer elements" do
        let(:params) { { answer: { block_ids: [ "a", "b" ] } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end

      context "when block_ids contains a negative or zero element" do
        let(:params) { { answer: { block_ids: [ 0, -1 ] } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end

      context "when block_ids contains an element beyond the postgres bigint range" do
        let(:params) { { answer: { block_ids: [ ReorderSangaku::POSTGRES_BIGINT_MAX + 1 ] } }.to_json }

        it "returns 400" do
          http_request

          expect(response).to have_http_status(400)
        end
      end
    end

    context "without the X-Client-Secret header", openapi: false do
      let(:params) { { answer: { block_ids: correct_block_ids } }.to_json }

      before do
        allow(Settings).to receive(:verify_client_secret).and_return(true)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("CLIENT_SECRET").and_return("expected_secret")
      end

      it "returns 403 without reaching the action" do
        http_request

        expect(response).to have_http_status(403)
        expect(body["message"]).to eq("Forbidden")
      end
    end
  end
end
