require 'rails_helper'

RSpec.describe "Api::V1::Public::ReorderSangakus", type: :request do
  describe "GET /public/reorder_sangakus/[:id]" do
    let!(:shrine) { create(:shrine) }
    let!(:reorder_sangaku) { create(:sangaku, :reorder, shrine: shrine) }
    let(:http_request) { get api_v1_public_reorder_sangaku_path(reorder_sangaku.id) }

    context "without authentication headers" do
      it "returns 200 for the shrine's representative reorder sangaku" do
        http_request

        expect(response).to have_http_status(200)
      end

      it "does not include correct_position in the code_blocks" do
        http_request

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks).to all(satisfy { |block| !block.key?("correct_position") })
      end

      it "returns the code_blocks belonging to the shrine's representative reorder sangaku" do
        http_request

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks.map { |block| block["content"] })
          .to match_array(reorder_sangaku.sangakuable.code_blocks.map(&:content))
      end
    end

    context "with a non-representative reorder sangaku id", openapi: false do
      let!(:representative_user_sangaku_save) { create(:user_sangaku_save, sangaku: reorder_sangaku) }
      let!(:representative_answer) { create(:answer, :reorder, user_sangaku_save: representative_user_sangaku_save) }
      let!(:non_representative_sangaku) { create(:sangaku, :reorder, shrine: shrine) }
      let(:http_request) { get api_v1_public_reorder_sangaku_path(non_representative_sangaku.id) }

      # 403 だと「存在するがアクセス権がない」ことになり、未認証のまま id の存在有無を
      # 推測できてしまう。存在しない id（下のcontext）と同じ 404 に倒す（issue #359）。
      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a code sangaku id", openapi: false do
      let!(:code_sangaku) { create(:sangaku, shrine: shrine) }
      let(:http_request) { get api_v1_public_reorder_sangaku_path(code_sangaku.id) }

      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a reorder sangaku that has not been dedicated to any shrine", openapi: false do
      let!(:undedicated_sangaku) { create(:sangaku, :reorder, shrine: nil) }
      let(:http_request) { get api_v1_public_reorder_sangaku_path(undedicated_sangaku.id) }

      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a nonexistent reorder sangaku id", openapi: false do
      let(:http_request) { get api_v1_public_reorder_sangaku_path(reorder_sangaku.id + 1_000_000) }

      it "return 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "without the X-Client-Secret header", openapi: false do
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
