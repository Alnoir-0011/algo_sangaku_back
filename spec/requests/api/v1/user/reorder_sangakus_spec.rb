require 'rails_helper'

RSpec.describe "Api::V1::User::ReorderSangakus", type: :request do
  describe "POST /api/v1/user/reorder_sangakus" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:code_blocks_params) do
      [
        { content: "puts 1", correct_position: 1 },
        { content: "puts 2", correct_position: 2 },
        { content: "dummy", correct_position: nil }
      ]
    end
    let(:params) { { sangaku: attributes_for(:reorder_sangaku_params), code_blocks: code_blocks_params } }
    let!(:user) { create(:user) }

    context "with access token" do
      before { authenticate_stub(user) }

      it "returns 200" do
        post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

        expect(response).to have_http_status(:ok)
      end

      it "creates a sangaku" do
        expect {
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json
        }.to change(Sangaku, :count).by(1)
      end

      it "creates a reorder_sangaku" do
        expect {
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json
        }.to change(ReorderSangaku, :count).by(1)
      end

      it "creates code_blocks for the given blocks" do
        expect {
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json
        }.to change(CodeBlock, :count).by(3)
      end

      it "returns the created sangaku's title in JSON:API format" do
        post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

        expect(body["data"]["attributes"]["title"]).to eq "test_title"
      end

      it "returns code_blocks with correct_position matching the submitted blocks", openapi: false do
        post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

        code_blocks = body["data"]["attributes"]["code_blocks"]
        expected_positions = code_blocks_params.map { |block| block[:correct_position] }

        expect(code_blocks.count).to eq code_blocks_params.count
        expect(code_blocks.map { |block| block["correct_position"] }).to match_array(expected_positions)
      end
    end

    context "without access token", openapi: false do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

      it "returns 401" do
        post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

        expect(response).to have_http_status(401)
      end

      it "does not create a sangaku" do
        expect {
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json
        }.not_to change(Sangaku, :count)
      end
    end

    # front は項目ごとのエラー表示に errors のキー名を使うため、
    # コード記述形式と同様にキー名を固定する特性テストとして用意する（issue #278）。
    describe "error keys in the 400 response" do
      let(:error_keys) { body["errors"].map(&:first) }

      before { authenticate_stub(user) }

      context "without a title", openapi: false do
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: ""), code_blocks: code_blocks_params } }

        it "returns the title error key" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "title"
        end
      end

      context "without a description", openapi: false do
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, description: ""), code_blocks: code_blocks_params } }

        it "returns the description error key" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "description"
        end
      end

      context "without a difficulty", openapi: false do
        # 空文字 "" は Rails の enum 代入時に ArgumentError になるため nil を使う
        # （spec/models/reorder_sangaku_spec.rb も difficulty: nil で presence を検証している）
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, difficulty: nil), code_blocks: code_blocks_params } }

        it "returns the difficulty error key" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "difficulty"
        end
      end

      # 親（title）と子（description）が同時に不正なとき、子の save! が先に失敗して
      # 親の検証が走らず title のキーが抜け落ちる不具合があった。両方のキーが返ることを固定する。
      context "without both a title and a description", openapi: false do
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: "", description: ""), code_blocks: code_blocks_params } }

        it "returns both the title and description error keys" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include("title", "description")
        end
      end

      # 大量の要素を送られてもメモリを使い切らないよう、ブロックを組み立てる前に件数で弾く
      context "with more code_blocks than MAX_CODE_BLOCKS", openapi: false do
        let(:code_blocks_params) { Array.new(ReorderSangaku::MAX_CODE_BLOCKS + 1) { |i| { content: "block_#{i}", correct_position: i + 1 } } }

        it "rejects the request before building any code_blocks" do
          expect_any_instance_of(ReorderSangaku).not_to receive(:save_with_code_blocks)

          expect {
            post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json
          }.not_to change(Sangaku, :count)
          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end

      context "with fewer than two correct code_blocks", openapi: false do
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "dummy", correct_position: nil }
          ]
        end

        it "returns the code_blocks error key" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end

      context "with a correct_position sequence that does not start from 1", openapi: false do
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "puts 3", correct_position: 3 }
          ]
        end

        it "returns the code_blocks error key" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end

      context "with more than 100 code_blocks", openapi: false do
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "puts 2", correct_position: 2 }
          ] + Array.new(99) { { content: "dummy", correct_position: nil } }
        end

        it "returns the code_blocks error key" do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end
    end

    # code_blocks は INSERT 前にシャッフルされるため、id の昇順だけから正解順（correct_position順）を
    # 推測できないことを検証する。ブロック数が少ないと偶然 id 順=正解順になり得るため、
    # 十分な数（12個）のブロックを使い、複数回の作成試行のうち少なくとも1回は
    # id 順の content が正解順と一致しないことを確認する（フレーキー回避）。
    describe "shuffling of persisted code_blocks" do
      let(:code_blocks_params) { (1..12).map { |i| { content: "block_#{i}", correct_position: i } } }

      before { authenticate_stub(user) }

      # この 200 レスポンスは "with access token" コンテキストの "returns 200" で
      # 既にドキュメント化されているため、OpenAPI ドキュメントへの重複記録を避ける
      it "does not persist code_blocks in id order matching the correct_position order every time", openapi: false do
        correct_order = (1..12).map { |i| "block_#{i}" }

        id_orders = Array.new(5) do
          post api_v1_user_reorder_sangakus_path, headers: headers, params: params.to_json
          sangaku_id = body["data"]["id"]
          Sangaku.find(sangaku_id).sangakuable.code_blocks.order(:id).pluck(:content)
        end

        # 「毎回同じ並びにはならない」＝少なくとも1回は正解順と異なる、という意図。
        # RSpec の all マッチャーは not_to と併用できない（NotImplementedError）ため any? で表現する。
        expect(id_orders.any? { |order| order != correct_order }).to eq true
      end
    end
  end

  describe "PATCH /api/v1/user/reorder_sangakus/:id" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:code_blocks_params) do
      [
        { content: "puts 1", correct_position: 1 },
        { content: "puts 2", correct_position: 2 },
        { content: "dummy", correct_position: nil }
      ]
    end
    let(:http_request) { patch api_v1_user_reorder_sangaku_path(sangaku.id), headers:, params: }

    context "with access token" do
      let!(:sangaku) { create(:sangaku, :reorder, title: "before_changed", description: "before_desc", difficulty: "easy", user: user) }
      let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: "changed_title", description: "changed_desc", difficulty: "difficult"), code_blocks: code_blocks_params }.to_json }

      it "updates title, description, and difficulty" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["title"]).to eq "changed_title"
        expect(body["data"]["attributes"]["description"]).to eq "changed_desc"
        expect(body["data"]["attributes"]["difficulty"]).to eq "difficult"
        sangaku.reload
        expect(sangaku.title).to eq "changed_title"
        expect(sangaku.sangakuable.description).to eq "changed_desc"
        expect(sangaku.sangakuable.difficulty).to eq "difficult"
      end
    end

    context "when code_blocks are provided" do
      let!(:sangaku) { create(:sangaku, :reorder, user: user) }
      let!(:old_block_ids) { sangaku.sangakuable.code_blocks.pluck(:id) }
      let(:params) { { sangaku: attributes_for(:reorder_sangaku_params), code_blocks: code_blocks_params }.to_json }

      it "replaces all code_blocks with the given ones" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        reloaded_contents = sangaku.reload.sangakuable.code_blocks.pluck(:content)
        expect(reloaded_contents).to match_array([ "puts 1", "puts 2", "dummy" ])
        expect(CodeBlock.where(id: old_block_ids)).to be_none
      end
    end

    context "without access_token", openapi: false do
      let!(:sangaku) { create(:sangaku, :reorder, title: "before_changed", user: user) }
      let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: "changed_title"), code_blocks: code_blocks_params }.to_json }
      let(:http_request) { patch api_v1_user_reorder_sangaku_path(sangaku.id), headers: { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' }, params: }

      it "returns 401 and does not change the sangaku" do
        http_request

        expect(response).to have_http_status(401)
        expect(sangaku.reload.title).to eq "before_changed"
      end
    end

    context "with nonexistent id", openapi: false do
      let!(:sangaku) { create(:sangaku, :reorder, user: user) }
      let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: "changed_title"), code_blocks: code_blocks_params }.to_json }
      let(:http_request) { patch api_v1_user_reorder_sangaku_path(1_000_000), headers:, params: }

      it "returns 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with another user's reorder_sangaku id", openapi: false do
      let!(:another_user) { create(:user) }
      let!(:sangaku) { create(:sangaku, :reorder, user: another_user) }
      let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: "changed_title"), code_blocks: code_blocks_params }.to_json }

      it "returns 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a code_sangaku's id", openapi: false do
      let!(:sangaku) { create(:sangaku, user: user) }
      let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: "changed_title"), code_blocks: code_blocks_params }.to_json }

      it "returns 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "error keys in the 400 response" do
      let!(:sangaku) { create(:sangaku, :reorder, user: user) }

      let(:error_keys) { body["errors"].map(&:first) }

      before { authenticate_stub(user) }

      context "with more code_blocks than MAX_CODE_BLOCKS", openapi: false do
        let(:code_blocks_params) { Array.new(ReorderSangaku::MAX_CODE_BLOCKS + 1) { |i| { content: "block_#{i}", correct_position: i + 1 } } }
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params), code_blocks: code_blocks_params }.to_json }

        it "rejects the request before building any code_blocks" do
          expect_any_instance_of(ReorderSangaku).not_to receive(:save_with_code_blocks)

          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
          expect(sangaku.sangakuable.code_blocks.count).to eq 2
        end
      end

      context "without a title", openapi: false do
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, title: ""), code_blocks: code_blocks_params }.to_json }

        it "returns the title error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "title"
        end
      end

      context "without a description", openapi: false do
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, description: ""), code_blocks: code_blocks_params }.to_json }

        it "returns the description error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "description"
        end
      end

      context "without a difficulty", openapi: false do
        # 空文字 "" は Rails の enum 代入時に ArgumentError になるため nil を使う
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params, difficulty: nil), code_blocks: code_blocks_params }.to_json }

        it "returns the difficulty error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "difficulty"
        end
      end

      context "with fewer than two correct code_blocks", openapi: false do
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "dummy", correct_position: nil }
          ]
        end
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params), code_blocks: code_blocks_params }.to_json }

        it "returns the code_blocks error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end

      context "with a correct_position sequence that does not start from 1", openapi: false do
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "puts 3", correct_position: 3 }
          ]
        end
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params), code_blocks: code_blocks_params }.to_json }

        it "returns the code_blocks error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end

      context "with more than 100 code_blocks", openapi: false do
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "puts 2", correct_position: 2 }
          ] + Array.new(99) { { content: "dummy", correct_position: nil } }
        end
        let(:params) { { sangaku: attributes_for(:reorder_sangaku_params), code_blocks: code_blocks_params }.to_json }

        it "returns the code_blocks error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "code_blocks"
        end
      end
    end
  end
end
