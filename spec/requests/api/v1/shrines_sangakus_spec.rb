require 'rails_helper'

RSpec.describe "Api::V1::ShrinesSangakus", type: :request do
  describe "GET /api/v1/shrine/{id}/sangakus" do
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, title: "test_title", difficulty: "normal", shrine: shrine) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:params) { {} }
    let(:http_request) { get api_v1_shrine_sangakus_path(shrine.id), headers:, params: }

    context "with access_token" do
      let(:params) { { title: "test_title", difficulty: "normal" } }
      it "return sangakus in json format" do
        http_request

        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"][0]["id"]).to eq sangaku.id.to_s
        expect(body["data"][0]["attributes"]["title"]).to eq sangaku.title
      end

      it "does not include source in response" do
        http_request

        expect(body["data"][0]["attributes"].keys).not_to include("source")
      end
    end

    context "with multiple sangakus created out of id order" do
      it "returns sangakus ordered by creation time descending regardless of id order" do
        oldest = create(:sangaku, id: sangaku.id + 100, title: "oldest", difficulty: "normal", shrine: shrine, created_at: 3.days.ago)
        newest = create(:sangaku, id: sangaku.id + 200, title: "newest", difficulty: "normal", shrine: shrine, created_at: 1.day.ago)
        middle = create(:sangaku, id: sangaku.id + 300, title: "middle", difficulty: "normal", shrine: shrine, created_at: 2.days.ago)

        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        target_ids = returned_ids & [ newest.id, middle.id, oldest.id ]
        expect(target_ids).to eq([ newest.id, middle.id, oldest.id ])
      end

      it "returns sangakus ordered by id descending when created_at is the same" do
        same_time = 1.day.ago
        first_created = create(:sangaku, id: sangaku.id + 100, title: "first", difficulty: "normal", shrine: shrine, created_at: same_time)
        second_created = create(:sangaku, id: sangaku.id + 200, title: "second", difficulty: "normal", shrine: shrine, created_at: same_time)

        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        target_ids = returned_ids & [ second_created.id, first_created.id ]
        expect(target_ids).to eq([ second_created.id, first_created.id ])
      end
    end

    # 並べ替え形式は fixed_inputs を持たないため、形式を分けずに参照すると一覧全体が 500 になる
    context "with a reorder sangaku dedicated to the shrine", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }

      it "returns both formats with empty inputs for the reorder sangaku" do
        http_request

        expect(response).to have_http_status(:ok)
        reorder_data = body["data"].find { |d| d["id"] == reorder_sangaku.id.to_s }
        expect(body["data"].map { |d| d["id"] }).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
        expect(reorder_data["attributes"]["inputs"]).to eq []
      end
    end

    # 一覧は件数分のブロックが乗って重くなるため code_blocks を返さない
    context "with a reorder sangaku dedicated to the shrine, when checking code_blocks", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }

      it "does not include code_blocks key in any sangaku's attributes" do
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"].map { |d| d["id"] }).to include(reorder_sangaku.id.to_s)
        expect(body["data"].map { |d| d["attributes"].key?("code_blocks") }.uniq).to eq [ false ]
      end
    end

    context "with kind=code" do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }
      let(:params) { { kind: "code" } }

      it "returns only code sangakus" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s)
        expect(returned_ids).not_to include(reorder_sangaku.id.to_s)
      end
    end

    context "with kind=reorder", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }
      let(:params) { { kind: "reorder" } }

      it "returns only reorder sangakus" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(reorder_sangaku.id.to_s)
        expect(returned_ids).not_to include(sangaku.id.to_s)
      end
    end

    context "without kind param", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }
      let(:params) { {} }

      it "returns both code and reorder sangakus" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
      end
    end

    context "with kind=all", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }
      let(:params) { { kind: "all" } }

      it "returns both code and reorder sangakus" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
      end
    end

    context "with an unknown kind value", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, title: "reorder_title", shrine: shrine) }
      let(:params) { { kind: "unknown" } }

      it "ignores the kind param and returns both code and reorder sangakus" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        expect(returned_ids).to include(sangaku.id.to_s, reorder_sangaku.id.to_s)
      end
    end

    context "with difficulty=normal", openapi: false do
      let!(:code_normal) { create(:sangaku, difficulty: "normal", shrine: shrine) }
      let!(:code_easy) { create(:sangaku, difficulty: "easy", shrine: shrine) }
      let!(:reorder_normal) { create(:sangaku, :reorder, difficulty: "normal", shrine: shrine) }
      let!(:reorder_easy) { create(:sangaku, :reorder, difficulty: "easy", shrine: shrine) }
      let(:created_ids) { [ code_normal.id, code_easy.id, reorder_normal.id, reorder_easy.id ].map(&:to_s) }
      let(:params) { { difficulty: "normal" } }

      it "returns only the normal difficulty sangakus from both formats" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        target_ids = returned_ids & created_ids
        expect(target_ids.sort).to eq([ code_normal.id.to_s, reorder_normal.id.to_s ].sort)
      end
    end

    context "with difficulty=normal and kind=reorder", openapi: false do
      let!(:code_normal) { create(:sangaku, difficulty: "normal", shrine: shrine) }
      let!(:code_easy) { create(:sangaku, difficulty: "easy", shrine: shrine) }
      let!(:reorder_normal) { create(:sangaku, :reorder, difficulty: "normal", shrine: shrine) }
      let!(:reorder_easy) { create(:sangaku, :reorder, difficulty: "easy", shrine: shrine) }
      let(:created_ids) { [ code_normal.id, code_easy.id, reorder_normal.id, reorder_easy.id ].map(&:to_s) }
      let(:params) { { difficulty: "normal", kind: "reorder" } }

      it "returns only the reorder sangaku with normal difficulty" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        target_ids = returned_ids & created_ids
        expect(target_ids).to eq([ reorder_normal.id.to_s ])
      end
    end

    context "with an unknown difficulty value", openapi: false do
      let!(:code_normal) { create(:sangaku, difficulty: "normal", shrine: shrine) }
      let!(:code_easy) { create(:sangaku, difficulty: "easy", shrine: shrine) }
      let!(:reorder_normal) { create(:sangaku, :reorder, difficulty: "normal", shrine: shrine) }
      let!(:reorder_easy) { create(:sangaku, :reorder, difficulty: "easy", shrine: shrine) }
      let(:created_ids) { [ code_normal.id, code_easy.id, reorder_normal.id, reorder_easy.id ].map(&:to_s) }
      let(:params) { { difficulty: "unknown" } }

      it "ignores the difficulty param and returns all four sangakus" do
        http_request

        expect(response).to have_http_status(:ok)
        returned_ids = body["data"].map { |d| d["id"] }
        target_ids = returned_ids & created_ids
        expect(target_ids.sort).to eq(created_ids.sort)
      end
    end

    context "with a nonexistent shrine_id", openapi: false do
      let(:http_request) { get api_v1_shrine_sangakus_path(shrine.id + 1_000_000), headers:, params: }

      it "return 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end
  end
end
