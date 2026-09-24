require 'rails_helper'

RSpec.describe "Api::V1::User::Sangakus", type: :request do
  describe "GET /index" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { get api_v1_user_sangakus_path, params: params, headers: headers }
    let!(:user) { create(:user) }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, user:, shrine:) }
    let!(:another_user) { create(:user, name: "another_user") }
    let!(:another_user_sangaku) { create(:sangaku, user: another_user) }

    context "with_accesstoken" do
      let(:params) { {} }

      it "return sangakus in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"][0]["id"]).to eq sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
      end
    end

    context "with multiple sangakus created out of id order", openapi: false do
      let(:params) { {} }

      it "returns sangakus ordered by creation time descending regardless of id order" do
        authenticate_stub(user)
        oldest = create(:sangaku, id: sangaku.id + 100, user:, created_at: 3.days.ago)
        newest = create(:sangaku, id: sangaku.id + 200, user:, created_at: 1.day.ago)
        middle = create(:sangaku, id: sangaku.id + 300, user:, created_at: 2.days.ago)

        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        target_ids = returned_ids & [ newest.id, middle.id, oldest.id ]
        expect(target_ids).to eq([ newest.id, middle.id, oldest.id ])
      end

      it "returns sangakus ordered by id descending when created_at is the same" do
        authenticate_stub(user)
        same_time = 1.day.ago
        first_created = create(:sangaku, id: sangaku.id + 100, user:, created_at: same_time)
        second_created = create(:sangaku, id: sangaku.id + 200, user:, created_at: same_time)

        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        target_ids = returned_ids & [ second_created.id, first_created.id ]
        expect(target_ids).to eq([ second_created.id, first_created.id ])
      end
    end

    # 一覧は件数分のブロックが乗って重くなるため code_blocks を返さない。
    # 奉納確認モーダルなど、ブロックが必要な画面は詳細（GET /user/sangakus/:id）を取り直す（issue #278）
    context "with a reorder sangaku in the list", openapi: false do
      let(:params) { {} }
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user:) }

      it "does not include code_blocks for any sangaku" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"].map { |d| d["id"] }).to include(reorder_sangaku.id.to_s)
        expect(body["data"].map { |d| d["attributes"].key?("code_blocks") }.uniq).to eq [ false ]
      end
    end

    context "search by title" do
      let(:params) { { title: "another" } }
      let!(:another_sangaku) { create(:sangaku, title: 'another_title', user:) }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq another_sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq another_sangaku.title
      end
    end

    context "search by shrine_id" do
      let!(:another_shrine) { create(:shrine, name: "another_shrine") }
      let!(:another_sangaku) { create(:sangaku, title: "another_shrine", user:, shrine: another_shrine) }
      let(:params) { { shrine_id: another_shrine.id } }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq another_sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq another_sangaku.title
      end
    end

    context "search befoer dedicate" do
      let!(:another_sangaku) { create(:sangaku, title: "before_dedicate", user:) }
      let(:params) { { shrine_id: "" } }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq another_sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq another_sangaku.title
      end
    end

    context "search after dedicate" do
      let!(:another_sangaku) { create(:sangaku, title: "before_dedicate", user:) }
      let(:params) { { shrine_id: "any" } }

      it "return search result in json format" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(body["data"].count).to eq 1
        expect(body["data"][0]["id"]).to eq sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
      end
    end

    context "with kind=code" do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user:) }
      let(:params) { { kind: "code" } }

      it "returns only code sangakus" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s)
        expect(returned_ids).not_to include(reorder_sangaku.id.to_s)
      end
    end

    context "with kind=reorder", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user:) }
      let(:params) { { kind: "reorder" } }

      it "returns only reorder sangakus" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(reorder_sangaku.id.to_s)
        expect(returned_ids).not_to include(sangaku.id.to_s)
      end
    end

    context "without kind param", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user:) }
      let(:params) { {} }

      it "returns both code and reorder sangakus" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
      end
    end

    context "with an unknown kind value", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user:) }
      let(:params) { { kind: "unknown" } }

      it "ignores the kind param and returns both code and reorder sangakus" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
      end
    end

    context "with difficulty=normal", openapi: false do
      let!(:code_normal) { create(:sangaku, difficulty: "normal", user:) }
      let!(:code_easy) { create(:sangaku, difficulty: "easy", user:) }
      let!(:reorder_normal) { create(:sangaku, :reorder, difficulty: "normal", user:) }
      let!(:reorder_easy) { create(:sangaku, :reorder, difficulty: "easy", user:) }
      let(:created_ids) { [ code_normal.id, code_easy.id, reorder_normal.id, reorder_easy.id ].map(&:to_s) }
      let(:params) { { difficulty: "normal" } }

      it "returns only the normal difficulty sangakus from both formats" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        target_ids = returned_ids & created_ids
        expect(target_ids.sort).to eq([ code_normal.id.to_s, reorder_normal.id.to_s ].sort)
      end
    end

    context "without access_token", openapi: false do
      let(:params) { {} }

      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end
  end

  describe "GET /user/sangakus/[id]" do
    let(:user) { create(:user) }
    let(:sangaku) { create(:sangaku, user:) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { {} }
    let(:http_request) { get api_v1_user_sangaku_path(sangaku.id), headers:, params: }

    context 'with_accesstoken' do
      it "return sangaku in json formata" do
        authenticate_stub(user)

        http_request

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(body["data"]["id"]).to eq sangaku.id.to_s
      end
    end

    context "without access_token", openapi: false do
      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
      end
    end

    context "with a nonexistent id", openapi: false do
      let(:http_request) { get api_v1_user_sangaku_path(sangaku.id + 1_000_000), headers:, params: }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with another user's sangaku id", openapi: false do
      let!(:another_user) { create(:user, nickname: "another") }
      let!(:another_sangaku) { create(:sangaku, user: another_user) }
      let(:http_request) { get api_v1_user_sangaku_path(another_sangaku.id), headers:, params: }

      it "return 404" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(404)
      end
    end

    context "with a code sangaku", openapi: false do
      it "returns kind code and type sangaku in the response" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["type"]).to eq "sangaku"
        expect(body["data"]["attributes"]["kind"]).to eq "code"
      end
    end

    context "with a reorder sangaku", openapi: false do
      let(:sangaku) { create(:sangaku, :reorder, user:) }

      it "returns kind reorder in the response" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["kind"]).to eq "reorder"
      end
    end

    context "with a code sangaku, when checking code_blocks", openapi: false do
      it "returns an empty array for code_blocks" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["code_blocks"]).to eq []
      end
    end

    context "with a reorder sangaku that includes dummy blocks inserted out of correct_position order", openapi: false do
      let(:sangaku) { create(:sangaku, :reorder, user:) }
      let(:reorder_sangaku) { sangaku.sangakuable }

      before { reorder_sangaku.code_blocks.destroy_all }

      # id の昇順とは違う順序になるよう、正解順・ダミーを混ぜてINSERTする
      let!(:dummy_first_inserted) { create(:code_block, reorder_sangaku:, content: "dummy_first_inserted", correct_position: nil) }
      let!(:second) { create(:code_block, reorder_sangaku:, content: "second", correct_position: 2) }
      let!(:dummy_second_inserted) { create(:code_block, reorder_sangaku:, content: "dummy_second_inserted", correct_position: nil) }
      let!(:first) { create(:code_block, reorder_sangaku:, content: "first", correct_position: 1) }

      it "returns code_blocks ordered by correct_position ascending then dummies by id ascending, each with id, content, and correct_position" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["code_blocks"]).to eq(
          [
            { "id" => first.id, "content" => "first", "correct_position" => 1 },
            { "id" => second.id, "content" => "second", "correct_position" => 2 },
            { "id" => dummy_first_inserted.id, "content" => "dummy_first_inserted", "correct_position" => nil },
            { "id" => dummy_second_inserted.id, "content" => "dummy_second_inserted", "correct_position" => nil }
          ]
        )
      end
    end
  end

  describe "DELETE /sangakus/[id]" do
    let!(:user) { create(:user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { {} }

    context "with with_accesstoken" do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { delete api_v1_user_sangaku_path(sangaku.id), headers: }

      it "return sangaku in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
      end
    end

    context "without access_token", openapi: false do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { delete api_v1_user_sangaku_path(sangaku.id), headers: { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

      it "return 401 errors" do
        expect {
          http_request
        }.not_to change(Sangaku, :count)
        expect(response).to have_http_status(401)
      end
    end

    context "with a fixed_input that has answer_results", openapi: false do
      let!(:sangaku) { create(:sangaku, user:) }
      let!(:fixed_input) { create(:fixed_input, sangaku: sangaku) }
      # CodeAnswer#create_results が code_sangaku.fixed_inputs を参照するため、
      # user_sangaku_save/answer を作る前に関連キャッシュを更新しておく必要がある
      before { sangaku.reload }
      let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku: sangaku) }
      let!(:answer) { create(:answer, user_sangaku_save: user_sangaku_save) }
      let(:http_request) { delete api_v1_user_sangaku_path(sangaku.id), headers: }

      it "deletes the sangaku along with its fixed_inputs and answer_results" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
      end
    end

    context "with nonexistent id", openapi: false do
      let!(:sangaku) { create(:sangaku, user:) }
      let(:http_request) { delete api_v1_user_sangaku_path(1000000000), headers: }

      it "return 404" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(0)
        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end

    context "with another_user sangaku", openapi: false do
      let!(:another_user) { create(:user, name: "another_user") }
      let!(:another_user_sangaku) { create(:sangaku, user: another_user) }
      let(:http_request) { delete api_v1_user_sangaku_path(another_user_sangaku), headers: }

      it "return 404" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(Sangaku, :count).by(0)
        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end
  end
end
