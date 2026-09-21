require 'rails_helper'

RSpec.describe "Api::V1::User::SavedSangakus", type: :request, openapi: { tags: %w[Api::V1::SangakuSave] } do
  describe "GET /index" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, user: author, shrine:) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let!(:answered_sangaku) { create(:sangaku, title: "answerd", user: author, shrine:) }
    let!(:answered_sangaku_save_relation) { create(:user_sangaku_save, sangaku: answered_sangaku, user: user) }
    let!(:answer) { create(:answer, user_sangaku_save: answered_sangaku_save_relation) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { type: "before_answer" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers:, params: }

    context "with access_token" do
      it 'return unsolved saved sangakus in json format' do
        authenticate_stub(user)
        http_request

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"][0]["attributes"]["author_name"]).to eq author.nickname
      end

      it "does not include source in response" do
        authenticate_stub(user)
        http_request

        expect(body["data"][0]["attributes"].keys).not_to include("source")
      end
    end

    context "with multiple unsolved saved sangakus created out of id order" do
      it "returns sangakus ordered by save time descending, independent of sangaku creation time" do
        authenticate_stub(user)
        newer_sangaku = create(:sangaku, title: "newer_sangaku", user: author, shrine:, created_at: 1.day.ago)
        older_sangaku = create(:sangaku, title: "older_sangaku", user: author, shrine:, created_at: 3.days.ago)

        # 保存日時は older_sangaku の方が新しい。保存レコードは older_sangaku を先に作り、
        # 保存の id の順（older < newer）と保存日時の順を逆にして、保存の id で並べる誤りも検出する
        create(:user_sangaku_save, sangaku: older_sangaku, user:, created_at: 1.hour.ago)
        create(:user_sangaku_save, sangaku: newer_sangaku, user:, created_at: 2.days.ago)

        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        target_ids = returned_ids & [ older_sangaku.id, newer_sangaku.id ]
        expect(target_ids).to eq([ older_sangaku.id, newer_sangaku.id ])
      end

      it "returns sangakus ordered by save id descending when saved_at is the same" do
        authenticate_stub(user)
        # 算額の id は s1 < s2 < s3
        s1 = create(:sangaku, title: "s1", user: author, shrine:)
        s2 = create(:sangaku, title: "s2", user: author, shrine:)
        s3 = create(:sangaku, title: "s3", user: author, shrine:)

        # 保存を s2 → s3 → s1 の順に作り、保存の id を s2 < s3 < s1 にする
        same_time = 1.day.ago
        create(:user_sangaku_save, sangaku: s2, user:, created_at: same_time)
        create(:user_sangaku_save, sangaku: s3, user:, created_at: same_time)
        create(:user_sangaku_save, sangaku: s1, user:, created_at: same_time)

        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        target_ids = returned_ids & [ s1.id, s2.id, s3.id ]
        # 保存の id の降順は [s1, s3, s2]。算額の id の昇順 [s1, s2, s3] とも降順 [s3, s2, s1] とも異なる
        expect(target_ids).to eq([ s1.id, s3.id, s2.id ])
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end
  end

  describe "GET /index with kind param" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers:, params: }

    context "without type param" do
      let!(:user) { create(:user) }
      let!(:code_sangaku) { create(:sangaku, user: create(:user)) }
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user: create(:user)) }

      before do
        create(:user_sangaku_save, sangaku: code_sangaku, user:)
        create(:user_sangaku_save, sangaku: reorder_sangaku, user:)
      end

      context "with kind=code" do
        let(:params) { { kind: "code" } }

        it "returns only code sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(code_sangaku.id.to_s)
          expect(returned_ids).not_to include(reorder_sangaku.id.to_s)
        end
      end

      context "with kind=reorder", openapi: false do
        let(:params) { { kind: "reorder" } }

        it "returns only reorder sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(reorder_sangaku.id.to_s)
          expect(returned_ids).not_to include(code_sangaku.id.to_s)
        end
      end

      context "without kind param", openapi: false do
        let(:params) { {} }

        it "returns both code and reorder sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(code_sangaku.id.to_s, reorder_sangaku.id.to_s)
        end
      end

      context "with an unknown kind value", openapi: false do
        let(:params) { { kind: "unknown" } }

        it "ignores the kind param and returns both code and reorder sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(code_sangaku.id.to_s, reorder_sangaku.id.to_s)
        end
      end
    end

    # index_scope は type によって search を通らない分岐があるため、
    # kind が type の指定に関わらず効くことを別途確かめる
    context "with type=before_answer", openapi: false do
      let!(:user) { create(:user) }
      let!(:code_sangaku) { create(:sangaku, user: create(:user)) }
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user: create(:user)) }

      before do
        create(:user_sangaku_save, sangaku: code_sangaku, user:)
        create(:user_sangaku_save, sangaku: reorder_sangaku, user:)
      end

      context "with kind=code" do
        let(:params) { { type: "before_answer", kind: "code" } }

        it "returns only code sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(code_sangaku.id.to_s)
          expect(returned_ids).not_to include(reorder_sangaku.id.to_s)
        end
      end

      context "with kind=reorder" do
        let(:params) { { type: "before_answer", kind: "reorder" } }

        it "returns only reorder sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(reorder_sangaku.id.to_s)
          expect(returned_ids).not_to include(code_sangaku.id.to_s)
        end
      end
    end

    # difficulty は形式ごとのテーブルが持つため、type=before_answer で両形式に絞り込みが効くことを確かめる。
    # type を指定しない保存一覧は difficulty の絞り込みを効かせない仕様のため、ここでは検証しない。
    context "with type=before_answer, when filtering by difficulty", openapi: false do
      let!(:user) { create(:user) }
      let!(:code_normal) { create(:sangaku, difficulty: "normal", user: create(:user)) }
      let!(:code_easy) { create(:sangaku, difficulty: "easy", user: create(:user)) }
      let!(:reorder_normal) { create(:sangaku, :reorder, difficulty: "normal", user: create(:user)) }
      let!(:reorder_easy) { create(:sangaku, :reorder, difficulty: "easy", user: create(:user)) }
      let(:created_ids) { [ code_normal.id, code_easy.id, reorder_normal.id, reorder_easy.id ].map(&:to_s) }

      before do
        create(:user_sangaku_save, sangaku: code_normal, user:)
        create(:user_sangaku_save, sangaku: code_easy, user:)
        create(:user_sangaku_save, sangaku: reorder_normal, user:)
        create(:user_sangaku_save, sangaku: reorder_easy, user:)
      end

      context "with difficulty=normal" do
        let(:params) { { type: "before_answer", difficulty: "normal" } }

        it "returns only the normal difficulty sangakus from both formats" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          target_ids = returned_ids & created_ids
          expect(target_ids.sort).to eq([ code_normal.id.to_s, reorder_normal.id.to_s ].sort)
        end
      end
    end

    # index_scope は type によって search を通らない分岐があるため、
    # kind が type の指定に関わらず効くことを別途確かめる
    context "with type=answered", openapi: false do
      let!(:user) { create(:user) }
      let!(:code_sangaku) { create(:sangaku, user: create(:user)) }
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user: create(:user)) }
      let!(:code_save) { create(:user_sangaku_save, sangaku: code_sangaku, user:) }
      let!(:reorder_save) { create(:user_sangaku_save, sangaku: reorder_sangaku, user:) }

      before do
        create(:answer, user_sangaku_save: code_save)
        create(:answer, :reorder, user_sangaku_save: reorder_save)
      end

      context "with kind=code" do
        let(:params) { { type: "answered", kind: "code" } }

        it "returns only code sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(code_sangaku.id.to_s)
          expect(returned_ids).not_to include(reorder_sangaku.id.to_s)
        end
      end

      context "with kind=reorder" do
        let(:params) { { type: "answered", kind: "reorder" } }

        it "returns only reorder sangakus" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          returned_ids = body["data"].map { |d| d["id"] }
          expect(returned_ids).to include(reorder_sangaku.id.to_s)
          expect(returned_ids).not_to include(code_sangaku.id.to_s)
        end
      end
    end
  end

  describe "GET /index ordered by save time", openapi: false do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers:, params: }

    # 算額の id（s1 < s2 < s3）・保存の id・保存日時の順番がすべて異なるデータを作る。
    # 保存日時の降順は [s1, s3, s2] で、算額の id の昇順 [s1, s2, s3]・降順 [s3, s2, s1]、
    # 保存の id の降順 [s2, s3, s1] のどれとも一致しないため、並べ方を取り違えると失敗する。
    # 戻り値は [保存日時の降順に並べた算額, 保存レコードの配列]
    def create_saves_in_mixed_order(titles: %w[s1 s2 s3])
      s1, s2, s3 = titles.map { |title| create(:sangaku, title:, user: author, shrine:) }
      saves = [
        create(:user_sangaku_save, sangaku: s1, user:, created_at: 1.day.ago),
        create(:user_sangaku_save, sangaku: s3, user:, created_at: 2.days.ago),
        create(:user_sangaku_save, sangaku: s2, user:, created_at: 3.days.ago)
      ]
      [ [ s1, s3, s2 ], saves ]
    end

    def returned_ids_of(sangakus)
      body["data"].map { |d| d["id"].to_i } & sangakus.map(&:id)
    end

    context "without type param" do
      let(:params) { {} }

      it "returns saved sangakus ordered by save time descending" do
        expected, = create_saves_in_mixed_order
        authenticate_stub(user)
        http_request

        expect(returned_ids_of(expected)).to eq(expected.map(&:id))
      end
    end

    context "with type=before_answer" do
      let(:params) { { type: "before_answer" } }

      it "returns saved sangakus ordered by save time descending" do
        expected, = create_saves_in_mixed_order
        authenticate_stub(user)
        http_request

        expect(returned_ids_of(expected)).to eq(expected.map(&:id))
      end
    end

    context "with type=answered" do
      let(:params) { { type: "answered" } }

      it "returns saved sangakus ordered by save time descending" do
        expected, saves = create_saves_in_mixed_order
        saves.each { |save| create(:answer, user_sangaku_save: save) }
        authenticate_stub(user)
        http_request

        expect(returned_ids_of(expected)).to eq(expected.map(&:id))
      end
    end

    context "when combining type=before_answer with a title filter" do
      let(:params) { { type: "before_answer", title: "shared_keyword" } }

      # DISTINCT を使う検索と保存日時での ORDER BY を組み合わせると
      # PostgreSQL の "for SELECT DISTINCT, ORDER BY expressions must appear in select list" が
      # 発生しやすい箇所のため、200 で返ることと並び順の両方を確認する
      it "returns 200 and orders the filtered results by save time descending" do
        expected, = create_saves_in_mixed_order(titles: %w[shared_keyword_1 shared_keyword_2 shared_keyword_3])
        # 一致しない算額は保存日時が最も新しくても返らない
        non_matching = create(:sangaku, title: "excluded_title", user: author, shrine:)
        create(:user_sangaku_save, sangaku: non_matching, user:, created_at: 1.hour.ago)
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"].map { |d| d["id"].to_i }).to eq(expected.map(&:id))
      end
    end
  end

  describe "GET /index with a saved reorder sangaku", openapi: false do
    let!(:user) { create(:user) }
    let!(:code_sangaku) { create(:sangaku, user: create(:user)) }
    let!(:reorder_sangaku) { create(:sangaku, :reorder, user: create(:user)) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    before do
      create(:user_sangaku_save, sangaku: code_sangaku, user:)
      create(:user_sangaku_save, sangaku: reorder_sangaku, user:)
    end

    it "returns both formats with empty inputs for the reorder sangaku" do
      authenticate_stub(user)
      get api_v1_user_saved_sangakus_path, headers:, params: { type: "before_answer" }

      expect(response).to have_http_status(:ok)
      expect(body["data"].map { |d| d["id"] }).to include(code_sangaku.id.to_s, reorder_sangaku.id.to_s)
      reorder_data = body["data"].find { |d| d["id"] == reorder_sangaku.id.to_s }
      expect(reorder_data["attributes"]["inputs"]).to eq []
    end
  end

  describe "GET /index with multiple users' answer status" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_saved_sangakus_path, headers:, params: }

    context "when another user has answered the same saved sangaku" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:shrine) { create(:shrine) }
      let!(:sangaku) { create(:sangaku, user: author, shrine:) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }
      let!(:other_answer) { create(:answer, user_sangaku_save: other_save) }

      context "with type=before_answer" do
        let(:params) { { type: "before_answer" } }

        it "includes the sangaku since current_user has not answered it yet" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).to include(sangaku.id.to_s)
        end
      end

      context "with type=answered" do
        let(:params) { { type: "answered" } }

        it "does not include the sangaku since current_user has not answered it" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).not_to include(sangaku.id.to_s)
        end
      end
    end

    context "when current_user has answered but another user has not" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:shrine) { create(:shrine) }
      let!(:sangaku) { create(:sangaku, user: author, shrine:) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:user_answer) { create(:answer, user_sangaku_save: user_save) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }

      context "with type=answered" do
        let(:params) { { type: "answered" } }

        it "includes the sangaku since current_user has answered it" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).to include(sangaku.id.to_s)
        end
      end

      context "with type=before_answer" do
        let(:params) { { type: "before_answer" } }

        it "does not include the sangaku since current_user has already answered it" do
          authenticate_stub(user)
          http_request

          expect(body["data"].map { |d| d["id"] }).not_to include(sangaku.id.to_s)
        end
      end
    end
  end

  describe "GET /show" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let!(:sangaku_save_relation) { create(:user_sangaku_save, sangaku:, user: user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { type: "before_answer" } }
    let(:http_request) { get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: }

    context "with access_token" do
      it 'return sangaku in json format' do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["title"]).to eq sangaku.title
        expect(body["data"]["attributes"]["author_name"]).to eq author.nickname
      end

      it "does not include source in response" do
        authenticate_stub(user)
        http_request

        expect(body["data"]["attributes"].keys).not_to include("source")
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end
  end

  describe "GET /show with a saved reorder sangaku", openapi: false do
    let!(:user) { create(:user) }
    let!(:reorder_sangaku) { create(:sangaku, :reorder, user: create(:user)) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    before { create(:user_sangaku_save, sangaku: reorder_sangaku, user:) }

    it "returns the reorder sangaku with empty inputs" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(reorder_sangaku.id), headers:, params: { type: "before_answer" }

      expect(response).to have_http_status(:ok)
      expect(body["data"]["attributes"]["title"]).to eq reorder_sangaku.title
      expect(body["data"]["attributes"]["inputs"]).to eq []
    end
  end

  # 解答画面で使う保存済み問題の詳細も、GET /sangakus/:id と同様に
  # 正解順（correct_position）やダミーかどうかが推測できない形で code_blocks を返す必要がある
  describe "GET /show with a saved reorder sangaku, when checking solver-facing code_blocks", openapi: false do
    let!(:user) { create(:user) }
    let!(:reorder_sangaku) do
      reorder = create(:sangaku, :reorder, user: create(:user)).sangakuable
      reorder.code_blocks.destroy_all
      12.times { |i| create(:code_block, reorder_sangaku: reorder, content: "block_#{i + 1}", correct_position: i + 1) }
      create(:code_block, reorder_sangaku: reorder, content: "dummy", correct_position: nil)
      reorder
    end
    let(:sangaku) { reorder_sangaku.sangaku }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    before { create(:user_sangaku_save, sangaku:, user:) }

    it "returns code_blocks whose elements have only id and content keys" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: { type: "before_answer" }

      code_blocks = body["data"]["attributes"]["code_blocks"]
      expect(code_blocks.map { |block| block.keys.sort }.uniq).to eq [ %w[content id] ]
    end

    it "returns all blocks including dummy blocks" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: { type: "before_answer" }

      code_blocks = body["data"]["attributes"]["code_blocks"]
      expect(code_blocks.size).to eq(13)
      expect(code_blocks.map { |block| block["content"] }.sort).to eq(reorder_sangaku.code_blocks.reload.pluck(:content).sort)
    end

    it "returns ids that belong to the sangaku's code blocks" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: { type: "before_answer" }

      code_blocks = body["data"]["attributes"]["code_blocks"]
      expect(code_blocks.map { |block| block["id"] }.sort).to eq(reorder_sangaku.code_blocks.reload.pluck(:id).sort)
    end

    it "does not leak correct_position in the response body" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: { type: "before_answer" }

      expect(response.body).not_to include("correct_position")
    end

    it "returns blocks in a different order across multiple requests" do
      authenticate_stub(user)

      orders = Array.new(5) do
        get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: { type: "before_answer" }
        body["data"]["attributes"]["code_blocks"].map { |block| block["id"] }
      end

      expect(orders.uniq.size).to be > 1
    end
  end

  # 並べ替え形式は提出した並びを保存しないため、解答結果の画面には正解コードを表示する。
  # 本人が解き終えた後はネタバレにならないため、解答済みのときだけ正解順で返す（issue #92）
  describe "GET /show with an answered reorder sangaku, when checking code_blocks", openapi: false do
    let!(:user) { create(:user) }
    let!(:reorder_sangaku) do
      reorder = create(:sangaku, :reorder, user: create(:user)).sangakuable
      reorder.code_blocks.destroy_all
      # id の昇順とは違う順序になるよう、正解順・ダミーを混ぜて INSERT する
      create(:code_block, reorder_sangaku: reorder, content: "dummy_first_inserted", correct_position: nil)
      create(:code_block, reorder_sangaku: reorder, content: "second", correct_position: 2)
      create(:code_block, reorder_sangaku: reorder, content: "dummy_second_inserted", correct_position: nil)
      create(:code_block, reorder_sangaku: reorder, content: "first", correct_position: 1)
      reorder
    end
    let(:sangaku) { reorder_sangaku.sangaku }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku:, user:) }

    before { create(:answer, :reorder, user_sangaku_save:, result: :incorrect) }

    it "returns code_blocks ordered by correct_position ascending then dummies by id ascending, each with correct_position" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(sangaku.id), headers: headers

      blocks_by_content = reorder_sangaku.code_blocks.reload.index_by(&:content)
      expect(body["data"]["attributes"]["code_blocks"]).to eq(
        [
          { "id" => blocks_by_content["first"].id, "content" => "first", "correct_position" => 1 },
          { "id" => blocks_by_content["second"].id, "content" => "second", "correct_position" => 2 },
          { "id" => blocks_by_content["dummy_first_inserted"].id, "content" => "dummy_first_inserted", "correct_position" => nil },
          { "id" => blocks_by_content["dummy_second_inserted"].id, "content" => "dummy_second_inserted", "correct_position" => nil }
        ]
      )
    end

    it "returns the same order across multiple requests" do
      authenticate_stub(user)

      orders = Array.new(3) do
        get api_v1_user_saved_sangaku_path(sangaku.id), headers: headers
        body["data"]["attributes"]["code_blocks"].map { |block| block["id"] }
      end

      expect(orders.uniq.size).to eq 1
    end

    # 他人が解答していても、自分が未解答なら正解は見えてはいけない
    it "does not leak correct_position to a user who has not answered it" do
      another_user = create(:user)
      create(:user_sangaku_save, sangaku:, user: another_user)
      authenticate_stub(another_user)

      get api_v1_user_saved_sangaku_path(sangaku.id), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("correct_position")
    end
  end

  describe "GET /show with a saved code sangaku, when checking code_blocks", openapi: false do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku) { create(:sangaku, user: author) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    before { create(:user_sangaku_save, sangaku:, user:) }

    it "returns an empty array for code_blocks" do
      authenticate_stub(user)
      get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: { type: "before_answer" }

      expect(body["data"]["attributes"]["code_blocks"]).to eq []
    end
  end

  # 保存一覧は件数分のブロックが乗って重くなるため code_blocks を返さない
  describe "GET /index with a saved reorder sangaku, when checking code_blocks", openapi: false do
    let!(:user) { create(:user) }
    let!(:reorder_sangaku) { create(:sangaku, :reorder, user: create(:user)) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    before { create(:user_sangaku_save, sangaku: reorder_sangaku, user:) }

    it "does not include code_blocks key in any sangaku's attributes" do
      authenticate_stub(user)
      get api_v1_user_saved_sangakus_path, headers:, params: { type: "before_answer" }

      expect(response).to have_http_status(:ok)
      expect(body["data"].map { |d| d["id"] }).to include(reorder_sangaku.id.to_s)
      expect(body["data"].map { |d| d["attributes"].key?("code_blocks") }.uniq).to eq [ false ]
    end
  end

  describe "GET /show with multiple users' answer status" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { type: "before_answer" } }
    let(:http_request) { get api_v1_user_saved_sangaku_path(sangaku.id), headers:, params: }

    context "when another user has answered the same saved sangaku but current_user has not" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:sangaku) { create(:sangaku, user: author) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }
      let!(:other_answer) { create(:answer, user_sangaku_save: other_save) }

      it "returns the sangaku" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["id"]).to eq sangaku.id.to_s
      end
    end

    context "when current_user has already answered the saved sangaku" do
      let!(:user) { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:author) { create(:user, nickname: "author") }
      let!(:sangaku) { create(:sangaku, user: author) }
      let!(:user_save) { create(:user_sangaku_save, sangaku:, user: user) }
      let!(:user_answer) { create(:answer, user_sangaku_save: user_save) }
      let!(:other_save) { create(:user_sangaku_save, sangaku:, user: other_user) }

      it "returns not found since current_user has already answered it" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
