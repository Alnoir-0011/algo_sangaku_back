require 'rails_helper'

RSpec.describe "Api::V1::Profiles", type: :request do
  describe "GET /show" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let!(:user) { create(:user) }
    let!(:shrine) { create(:shrine) }
    let!(:dedicated_sangaku) { create(:sangaku, user:, shrine:) }
    let!(:undedicated_sangaku) { create(:sangaku, user:) }
    let(:http_request) { get api_v1_profile_path(user.id), headers: }

    context "認証なしでアクセスできる" do
      it "200を返す", openapi: false do
        http_request
        expect(response).to have_http_status(:ok)
      end

      it "ニックネームを返す", openapi: false do
        http_request
        expect(body["data"]["attributes"]["nickname"]).to eq user.nickname
      end

      it "登録日を返す", openapi: false do
        http_request
        expect(body["data"]["attributes"]["created_at"]).to be_present
      end

      it "算額数を返す", openapi: false do
        http_request
        expect(body["data"]["attributes"]["sangaku_count"]).to eq 2
      end

      it "奉納済み算額数を返す", openapi: false do
        http_request
        expect(body["data"]["attributes"]["dedicated_sangaku_count"]).to eq 1
      end

      it "奉納済み算額一覧を返す（タイトル・神社名を含む）" do
        http_request
        dedicated = body["data"]["attributes"]["dedicated_sangakus"]
        expect(dedicated.length).to eq 1
        expect(dedicated[0]["title"]).to eq dedicated_sangaku.title
        expect(dedicated[0]["shrine_name"]).to eq shrine.name
      end

      it "emailを返さない", openapi: false do
        http_request
        expect(body["data"]["attributes"]).not_to have_key("email")
      end
    end

    context "show_answer_count が false のユーザー", openapi: false do
      it "answer_count が nil を返す" do
        user.update!(show_answer_count: false)
        http_request
        expect(body["data"]["attributes"]["answer_count"]).to be_nil
      end
    end

    context "show_answer_count が true のユーザー", openapi: false do
      it "answer_count を返す" do
        user.update!(show_answer_count: true)
        http_request
        expect(body["data"]["attributes"]["answer_count"]).to eq 0
      end
    end

    context "存在しないユーザーID", openapi: false do
      it "404を返す" do
        get api_v1_profile_path(0), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
