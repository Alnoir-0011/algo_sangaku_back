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
      let!(:other_sangaku) { create(:sangaku, id: sangaku.id - 1, title: "other_title", difficulty: "normal", shrine: shrine) }

      it "returns sangakus in ascending id order regardless of creation order" do
        http_request

        returned_ids = body["data"].map { |d| d["id"].to_i }
        expect(returned_ids).to eq([ other_sangaku.id, sangaku.id ])
      end

      it "issues a query with an explicit ascending id order" do
        queries = capture_executed_sql { http_request }
        expect(queries).to include(a_string_matching(/ORDER BY "sangakus"\."id" ASC/i))
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

    context "with a nonexistent shrine_id", openapi: false do
      let(:http_request) { get api_v1_shrine_sangakus_path(shrine.id + 1_000_000), headers:, params: }

      it "return 404" do
        http_request

        expect(response).to have_http_status(404)
      end
    end
  end
end
