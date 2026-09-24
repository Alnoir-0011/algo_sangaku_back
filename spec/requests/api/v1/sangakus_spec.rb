require 'rails_helper'

RSpec.describe "Api::V1::Sangakus", type: :request do
  describe "GET /sangakus/[id]" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { {} }

    context "with_accesstoken" do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "return sangakus in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["title"]).to eq sangaku.title
      end

      it "does not include source in response" do
        authenticate_stub(user)

        http_request
        expect(body["data"]["attributes"].keys).not_to include("source")
      end
    end

    context "with a reorder sangaku", openapi: false do
      let!(:sangaku) { create(:sangaku, :reorder, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "returns the sangaku with empty inputs" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"]["attributes"]["inputs"]).to eq []
      end
    end

    context "with nonexistent id", openapi: false do
      let(:http_request) { get api_v1_sangaku_path(1000000) }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
      expect(response).not_to be_successful
      end
    end

    context "with a code sangaku", openapi: false do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "returns kind code in the response" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "code"
      end
    end

    context "with a reorder sangaku for the kind attribute", openapi: false do
      let!(:sangaku) { create(:sangaku, :reorder, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "returns kind reorder in the response" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "reorder"
      end
    end

    # 解答者向け（GET /sangakus/:id）の code_blocks は、正解順（correct_position）や
    # ダミーかどうかが推測できない形で返す必要がある
    context "with a reorder sangaku, when checking solver-facing code_blocks", openapi: false do
      let!(:reorder_sangaku) do
        # 作者には正解順を見せるため、解答者としての振る舞いを見るここでは別のユーザーが作った算額を使う
        reorder = create(:sangaku, :reorder, user: create(:user)).sangakuable
        reorder.code_blocks.destroy_all
        12.times { |i| create(:code_block, reorder_sangaku: reorder, content: "block_#{i + 1}", correct_position: i + 1) }
        create(:code_block, reorder_sangaku: reorder, content: "dummy", correct_position: nil)
        reorder
      end
      let(:sangaku) { reorder_sangaku.sangaku }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "returns code_blocks whose elements have only id and content keys" do
        authenticate_stub(user)

        http_request

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks.map { |block| block.keys.sort }.uniq).to eq [ %w[content id] ]
      end

      it "returns all blocks including dummy blocks" do
        authenticate_stub(user)

        http_request

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks.size).to eq(13)
        expect(code_blocks.map { |block| block["content"] }.sort).to eq(reorder_sangaku.code_blocks.reload.pluck(:content).sort)
      end

      it "returns ids that belong to the sangaku's code blocks" do
        authenticate_stub(user)

        http_request

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks.map { |block| block["id"] }.sort).to eq(reorder_sangaku.code_blocks.reload.pluck(:id).sort)
      end

      it "does not leak correct_position in the response body" do
        authenticate_stub(user)

        http_request

        expect(response.body).not_to include("correct_position")
      end

      it "returns blocks in a different order across multiple requests" do
        authenticate_stub(user)

        orders = Array.new(5) do
          get api_v1_sangaku_path(sangaku.id)
          body["data"]["attributes"]["code_blocks"].map { |block| block["id"] }
        end

        expect(orders.uniq.size).to be > 1
      end
    end

    context "with a code sangaku, when checking code_blocks", openapi: false do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "returns an empty array for code_blocks" do
        authenticate_stub(user)

        http_request

        expect(body["data"]["attributes"]["code_blocks"]).to eq []
      end
    end

    # 解答済みなら本人は既に解き終えているためネタバレにならない。
    # 公開詳細も保存済み算額の詳細と同じ扱いにする（issue #92）
    context "with a reorder sangaku the current_user has already answered", openapi: false do
      let!(:reorder_sangaku) do
        reorder = create(:sangaku, :reorder, user: create(:user)).sangakuable
        reorder.code_blocks.destroy_all
        create(:code_block, reorder_sangaku: reorder, content: "dummy", correct_position: nil)
        create(:code_block, reorder_sangaku: reorder, content: "second", correct_position: 2)
        create(:code_block, reorder_sangaku: reorder, content: "first", correct_position: 1)
        reorder
      end
      let(:sangaku) { reorder_sangaku.sangaku }
      let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku:, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      before { create(:answer, :reorder, user_sangaku_save:, result: :correct) }

      it "returns code_blocks in correct_position order with correct_position included" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["code_blocks"].map { |block| block["content"] }).to eq(
          [ "first", "second", "dummy" ]
        )
        expect(body["data"]["attributes"]["code_blocks"].last["correct_position"]).to be_nil
      end

      it "does not put the response in a shared cache" do
        authenticate_stub(user)

        http_request

        expect(response.headers["Cache-Control"]).to include "no-store"
      end
    end

    # 作者は作者向けの詳細で既に正解順を見られるため、この経路でも隠す意味がない（issue #92）
    context "with a reorder sangaku the current_user is the author of", openapi: false do
      let!(:sangaku) { create(:sangaku, :reorder, user:) }
      let(:http_request) { get api_v1_sangaku_path(sangaku.id) }

      it "returns code_blocks with correct_position to the author" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["code_blocks"].map { |block| block["correct_position"] }).to eq [ 1, 2 ]
      end
    end
  end
end
