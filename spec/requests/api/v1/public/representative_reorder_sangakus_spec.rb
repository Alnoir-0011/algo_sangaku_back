require 'rails_helper'

RSpec.describe "Api::V1::Public::RepresentativeReorderSangakus", type: :request do
  describe "GET /public/shrines/[:shrine_id]/representative_reorder_sangaku" do
    let!(:shrine) { create(:shrine) }
    let(:http_request) { get api_v1_public_shrine_representative_reorder_sangaku_path(shrine.id) }

    context "when the shrine has a reorder sangaku" do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, shrine: shrine) }

      it "returns 200" do
        http_request

        expect(response).to have_http_status(200)
      end

      it "returns the representative reorder sangaku's code_blocks without correct_position" do
        http_request

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks.map { |block| block["content"] })
          .to match_array(reorder_sangaku.sangakuable.code_blocks.map(&:content))
        expect(code_blocks).to all(satisfy { |block| !block.key?("correct_position") })
      end

      it "returns the most answered reorder sangaku when the shrine has multiple" do
        fewer_answers_sangaku = reorder_sangaku
        most_answers_sangaku = create(:sangaku, :reorder, shrine: shrine)
        user_sangaku_save = create(:user_sangaku_save, sangaku: most_answers_sangaku)
        create(:answer, :reorder, user_sangaku_save: user_sangaku_save)

        http_request

        expect(body["data"]["id"]).to eq most_answers_sangaku.id.to_s
        expect(body["data"]["id"]).not_to eq fewer_answers_sangaku.id.to_s
      end
    end

    context "when the shrine has no reorder sangaku", openapi: false do
      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "when the shrine has only a code sangaku", openapi: false do
      let!(:code_sangaku) { create(:sangaku, shrine: shrine) }

      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a nonexistent shrine id", openapi: false do
      let(:http_request) { get api_v1_public_shrine_representative_reorder_sangaku_path(shrine.id + 1_000_000) }

      it "returns 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "without the X-Client-Secret header", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, shrine: shrine) }

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
