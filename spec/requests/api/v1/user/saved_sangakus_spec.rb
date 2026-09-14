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
      let!(:other_sangaku) { create(:sangaku, id: sangaku.id - 1, title: "other", user: author, shrine:) }
      let!(:other_sangaku_save_relation) { create(:user_sangaku_save, sangaku: other_sangaku, user: user) }

      it "returns sangakus in ascending id order regardless of creation order" do
        authenticate_stub(user)
        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        expect(returned_ids).to eq([ other_sangaku.id, sangaku.id ])
      end

      it "issues a query with an explicit ascending id order" do
        authenticate_stub(user)
        queries = capture_executed_sql { http_request }
        expect(queries).to include(a_string_matching(/ORDER BY "sangakus"\."id" ASC/i))
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
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
