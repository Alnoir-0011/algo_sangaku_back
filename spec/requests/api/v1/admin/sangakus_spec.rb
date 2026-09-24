require 'rails_helper'

RSpec.describe "Api::V1::Admin::Sangakus", type: :request do
  let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
  let!(:admin_user) { create(:user, :admin) }
  let!(:general_user) { create(:user) }
  let!(:sangaku) { create(:sangaku, user: general_user) }

  describe "GET /api/v1/admin/sangakus" do
    context "as admin" do
      it "returns 200 with sangakus list" do
        authenticate_stub(admin_user)
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]).to be_an(Array)
      end
    end

    # 一覧のシリアライザは形式ごとのテーブル（description / difficulty / source）を読むため、
    # 事前に読み込まないと算額 1 件ごとにクエリが増える（issue #278）
    context "when the number of sangakus increases", openapi: false do
      it "does not increase the number of executed queries" do
        authenticate_stub(admin_user)
        count_queries = lambda do
          capture_executed_sql { get api_v1_admin_sangakus_path, headers: headers }
            .count { |sql| sql.match?(/\ASELECT/i) }
        end

        create(:sangaku, :reorder, user: general_user)
        # 最初のリクエストだけ列情報の読み込みなど一度きりのクエリが走るため、先に 1 回送って済ませておく
        count_queries.call
        queries_before = count_queries.call

        2.times { create(:sangaku, user: general_user) }
        create(:sangaku, :reorder, user: general_user)
        queries_after = count_queries.call

        expect(queries_after).to eq queries_before
      end
    end

    context "with a reorder sangaku", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user: general_user) }

      it "returns both formats with a nil source for the reorder sangaku" do
        authenticate_stub(admin_user)
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"].map { |d| d["id"] }).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
        reorder_data = body["data"].find { |d| d["id"] == reorder_sangaku.id.to_s }
        expect(reorder_data["attributes"]["source"]).to be_nil
      end
    end

    context "with a reorder sangaku in the list", openapi: false do
      it "does not include a code_blocks key in the response" do
        # Arrange
        reorder_sangaku = create(:sangaku, :reorder, user: general_user)
        authenticate_stub(admin_user)

        # Act
        get api_v1_admin_sangakus_path, headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        reorder_data = body["data"].find { |d| d["id"] == reorder_sangaku.id.to_s }
        expect(reorder_data["attributes"]).not_to have_key("code_blocks")
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/admin/sangakus/:id" do
    context "as admin" do
      it "returns 200 with sangaku attributes" do
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs).to include("title", "description", "source", "difficulty", "created_at")
      end

      it "returns 200 with a nil source for a reorder sangaku", openapi: false do
        reorder_sangaku = create(:sangaku, :reorder, user: general_user)
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(reorder_sangaku.id), headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["title"]).to eq reorder_sangaku.title
        expect(body["data"]["attributes"]["source"]).to be_nil
      end

      it "returns 404 for nonexistent sangaku", openapi: false do
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns kind code in the response for a code sangaku", openapi: false do
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "code"
      end

      it "returns kind reorder in the response for a reorder sangaku", openapi: false do
        reorder_sangaku = create(:sangaku, :reorder, user: general_user)
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(reorder_sangaku.id), headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "reorder"
      end

      it "returns an empty array for code_blocks for a code sangaku", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["code_blocks"]).to eq []
      end

      it "returns id, content, and correct_position keys for each code_block of a reorder sangaku", openapi: false do
        # Arrange
        reorder_sangaku = create(:sangaku, :reorder, user: general_user)
        authenticate_stub(admin_user)

        # Act
        get api_v1_admin_sangaku_path(reorder_sangaku.id), headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        block = body["data"]["attributes"]["code_blocks"].first
        expect(block.keys).to match_array(%w[id content correct_position])
      end

      it "orders code_blocks by correct_position ascending with dummies last by id", openapi: false do
        # Arrange
        reorder_sangaku = create(:sangaku, :reorder, user: general_user).sangakuable
        reorder_sangaku.code_blocks.destroy_all
        create(:code_block, reorder_sangaku:, content: "dummy", correct_position: nil)
        create(:code_block, reorder_sangaku:, content: "second", correct_position: 2)
        create(:code_block, reorder_sangaku:, content: "first", correct_position: 1)
        authenticate_stub(admin_user)

        # Act
        get api_v1_admin_sangaku_path(reorder_sangaku.sangaku.id), headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        contents = body["data"]["attributes"]["code_blocks"].map { |block| block["content"] }
        expect(contents).to eq [ "first", "second", "dummy" ]
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/admin/sangakus/:id" do
    let(:new_params) do
      {
        sangaku: {
          title: "更新タイトル",
          difficulty: "normal",
          description: "更新説明文",
          source: "puts 'updated'"
        }
      }
    end

    context "as admin" do
      it "returns 200 and updates the sangaku" do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: new_params.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs["title"]).to eq("更新タイトル")
        expect(attrs["difficulty"]).to eq("normal")
        expect(attrs["description"]).to eq("更新説明文")
        expect(attrs["source"]).to eq("puts 'updated'")
      end

      it "returns 400 when title is blank", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: { sangaku: { title: "" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when difficulty is invalid", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: { sangaku: { difficulty: "invalid_value" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      # ブロックの編集は後続の対応で追加する。形式に合わない source は受け付けず無視する
      it "updates a reorder sangaku and ignores the source param", openapi: false do
        # Arrange
        reorder_sangaku = create(:sangaku, :reorder, user: general_user)
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(reorder_sangaku.id),
              params: new_params.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs["title"]).to eq("更新タイトル")
        expect(attrs["description"]).to eq("更新説明文")
        expect(attrs["difficulty"]).to eq("normal")
        expect(attrs["source"]).to be_nil
        expect(reorder_sangaku.sangakuable.code_blocks.count).to eq 2
      end

      it "returns code_blocks for a reorder sangaku in the response", openapi: false do
        # Arrange
        reorder_sangaku = create(:sangaku, :reorder, user: general_user)
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(reorder_sangaku.id),
              params: new_params.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        code_blocks = body["data"]["attributes"]["code_blocks"]
        expect(code_blocks.map { |block| block["content"] }).to match_array([ "code_block_1", "code_block_2" ])
      end

      context "when code_blocks are provided for a reorder sangaku", openapi: false do
        let!(:reorder_sangaku) { create(:sangaku, :reorder, user: general_user) }
        let!(:old_block_ids) { reorder_sangaku.sangakuable.code_blocks.pluck(:id) }
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "puts 2", correct_position: 2 },
            { content: "dummy", correct_position: nil }
          ]
        end
        let(:params) do
          {
            sangaku: { title: "更新タイトル", description: "更新説明文", difficulty: "normal" },
            code_blocks: code_blocks_params
          }
        end

        it "replaces all code_blocks with the given ones" do
          # Arrange
          authenticate_stub(admin_user)

          # Act
          patch api_v1_admin_sangaku_path(reorder_sangaku.id),
                params: params.to_json,
                headers: headers

          # Assert
          expect(response).to have_http_status(:ok)
          reloaded_blocks = CodeBlock.where(reorder_sangaku_id: reorder_sangaku.sangakuable.id)
          expect(reloaded_blocks.count).to eq 3
          expect(reloaded_blocks.pluck(:content, :correct_position)).to match_array(
            [ [ "puts 1", 1 ], [ "puts 2", 2 ], [ "dummy", nil ] ]
          )
          expect(CodeBlock.where(id: old_block_ids)).to be_none
        end
      end

      context "when the submitted code_blocks composition is invalid for a reorder sangaku", openapi: false do
        let!(:reorder_sangaku) { create(:sangaku, :reorder, user: general_user) }
        let(:params) do
          {
            sangaku: { title: "更新タイトル" },
            code_blocks: [
              { content: "puts 1", correct_position: 1 },
              { content: "dummy", correct_position: nil }
            ]
          }
        end

        it "returns 400 and does not update the sangaku" do
          # Arrange
          authenticate_stub(admin_user)

          # Act
          patch api_v1_admin_sangaku_path(reorder_sangaku.id),
                params: params.to_json,
                headers: headers

          # Assert
          expect(response).to have_http_status(:bad_request)
          expect(reorder_sangaku.reload.title).not_to eq "更新タイトル"
          expect(reorder_sangaku.sangakuable.code_blocks.reload.pluck(:content)).to match_array([ "code_block_1", "code_block_2" ])
        end
      end

      # permit はハッシュ以外の要素を黙って捨てるため、そのままだと送った数より
      # 少ないブロックで保存されてしまう。組み立てる前に弾く
      context "when a non-hash element is mixed into code_blocks for a reorder sangaku", openapi: false do
        let!(:reorder_sangaku) { create(:sangaku, :reorder, user: general_user) }
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            "not_a_hash",
            { content: "puts 2", correct_position: 2 }
          ]
        end
        let(:params) { { sangaku: { title: "更新タイトル" }, code_blocks: code_blocks_params } }

        it "returns 400 and does not change the code_blocks" do
          # Arrange
          authenticate_stub(admin_user)
          expect_any_instance_of(ReorderSangaku).not_to receive(:save_with_code_blocks)

          # Act
          patch api_v1_admin_sangaku_path(reorder_sangaku.id),
                params: params.to_json,
                headers: headers

          # Assert
          expect(response).to have_http_status(:bad_request)
          expect(body["errors"]).to include "code_blocksの形式が不正です"
          expect(reorder_sangaku.sangakuable.code_blocks.reload.count).to eq 2
          expect(reorder_sangaku.reload.title).not_to eq "更新タイトル"
        end
      end

      context "when code_blocks exceed MAX_CODE_BLOCKS for a reorder sangaku", openapi: false do
        let!(:reorder_sangaku) { create(:sangaku, :reorder, user: general_user) }
        let(:code_blocks_params) do
          [
            { content: "puts 1", correct_position: 1 },
            { content: "puts 2", correct_position: 2 }
          ] + Array.new(ReorderSangaku::MAX_CODE_BLOCKS) { { content: "dummy", correct_position: nil } }
        end
        let(:params) { { sangaku: { title: "更新タイトル" }, code_blocks: code_blocks_params } }

        it "returns 400 and does not change the code_blocks" do
          # Arrange
          authenticate_stub(admin_user)

          # Act
          patch api_v1_admin_sangaku_path(reorder_sangaku.id),
                params: params.to_json,
                headers: headers

          # Assert
          expect(response).to have_http_status(:bad_request)
          expect(reorder_sangaku.sangakuable.code_blocks.reload.count).to eq 2
        end
      end

      # 空の配列は「送られていない」ではなく「ブロックを 0 個にする」指定として扱い、構成エラーにする。
      # 送られていない扱いにすると、ブロックを全部消して保存しても何も起きず成功したように見えてしまう
      context "when an empty code_blocks array is provided for a reorder sangaku", openapi: false do
        let!(:reorder_sangaku) { create(:sangaku, :reorder, user: general_user) }
        let(:params) { { sangaku: { title: "更新タイトル" }, code_blocks: [] } }

        it "returns 400 and does not change the sangaku" do
          # Arrange
          authenticate_stub(admin_user)

          # Act
          patch api_v1_admin_sangaku_path(reorder_sangaku.id),
                params: params.to_json,
                headers: headers

          # Assert
          expect(response).to have_http_status(:bad_request)
          expect(reorder_sangaku.reload.title).not_to eq "更新タイトル"
          expect(reorder_sangaku.sangakuable.code_blocks.reload.count).to eq 2
        end
      end

      context "with a code sangaku", openapi: false do
        let(:params) do
          {
            sangaku: { title: "更新タイトル" },
            code_blocks: [ { content: "puts 1", correct_position: 1 } ]
          }
        end

        it "ignores the code_blocks param and updates the sangaku" do
          # Arrange
          authenticate_stub(admin_user)

          # Act
          patch api_v1_admin_sangaku_path(sangaku.id),
                params: params.to_json,
                headers: headers

          # Assert
          expect(response).to have_http_status(:ok)
          expect(body["data"]["attributes"]["title"]).to eq "更新タイトル"
        end
      end

      it "returns 404 for nonexistent sangaku", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(0),
              params: new_params.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: new_params.to_json,
              headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: new_params.to_json,
              headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/admin/sangakus/:id" do
    context "as admin" do
      it "returns 200 and deletes the sangaku" do
        authenticate_stub(admin_user)
        expect {
          delete api_v1_admin_sangaku_path(sangaku.id), headers: headers
        }.to change(Sangaku, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for nonexistent sangaku", openapi: false do
        authenticate_stub(admin_user)
        delete api_v1_admin_sangaku_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 200 and deletes the sangaku when a fixed_input has answer_results", openapi: false do
        fixed_input = create(:fixed_input, sangaku: sangaku)
        sangaku.reload
        user_sangaku_save = create(:user_sangaku_save, sangaku: sangaku)
        create(:answer, user_sangaku_save: user_sangaku_save)

        authenticate_stub(admin_user)
        expect {
          delete api_v1_admin_sangaku_path(sangaku.id), headers: headers
        }.to change(Sangaku, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(FixedInput.exists?(fixed_input.id)).to eq false
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        delete api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        delete api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
