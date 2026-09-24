require 'rails_helper'

RSpec.describe "Api::V1::User::CodeSangakus", type: :request do
  describe "POST /api/v1/user/code_sangakus" do
    context "with_accesstoken" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
      let(:params) { { sangaku: attributes_for(:sangaku_params), fixed_inputs: [ attributes_for(:fixed_input)[:content] ] } }
      let!(:user) { create(:user) }

      it "success to create sangaku" do
        authenticate_stub(user)

        expect {
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json
        }.to change(Sangaku, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end
    end

    context "without access_token", openapi: false do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
      let(:params) { { sangaku: attributes_for(:sangaku_params) } }

      it "return 401 errors" do
        expect {
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json
        }.not_to change(Sangaku, :count)
        expect(response).to have_http_status(401)
      end
    end

    context "with invalid params", openapi: false do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "") } }
      let!(:user) { create(:user) }

      it "return 400 errors" do
        authenticate_stub(user)

        expect {
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json
        }.not_to change(Sangaku, :count)
        expect(response).to have_http_status(400)
      end
    end

    # front は項目ごとのエラー表示に errors のキー名を使っているため、
    # delegated_type 移行後もキー名が変わらないことを固定する特性テスト（issue #278）。
    describe "error keys in the 400 response" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
      let!(:user) { create(:user) }
      let(:error_keys) { body["errors"].map(&:first) }

      before { authenticate_stub(user) }

      context "without a title", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, title: ""), fixed_inputs: [ "input_a" ] } }

        it "returns the title error key" do
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "title"
        end
      end

      context "without a description", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, description: ""), fixed_inputs: [ "input_a" ] } }

        it "returns the description error key" do
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "description"
        end
      end

      context "without a source", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, source: ""), fixed_inputs: [ "input_a" ] } }

        it "returns the source error key" do
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "source"
        end
      end

      context "without both a title and a description", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, title: "", description: ""), fixed_inputs: [ "input_a" ] } }

        it "returns both the title and description error keys" do
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include("title", "description")
        end
      end

      context "with an unknown difficulty", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, difficulty: "invalid_value"), fixed_inputs: [ "input_a" ] } }

        it "returns 400 with the difficulty error key" do
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "difficulty"
        end
      end

      context "with duplicated fixed_inputs", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params), fixed_inputs: [ "duplicated", "duplicated" ] } }

        it "returns the fixed_inputs error key" do
          post api_v1_user_code_sangakus_path, headers: headers, params: params.to_json

          expect(response).to have_http_status(400)
          expect(error_keys).to include "fixed_inputs"
        end
      end
    end
  end

  describe "PATCH /api/v1/user/code_sangakus/:id" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { {} }

    context "with_accesstoken" do
      let!(:sangaku) { create(:sangaku, title: "before_changed", user: user) }
      let(:http_request) { patch api_v1_user_code_sangaku_path(sangaku.id), headers:, params: }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "changed_title"), fixed_inputs: [ "a" ] }.to_json }

      it "success to update sangaku" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["title"]).to eq "changed_title"
      end
    end

    context "with nonexistent id", openapi: false do
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "changed_title") }.to_json }
      let(:http_request) { patch api_v1_user_code_sangaku_path(1000000), headers:, params: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end

    context "without access_token", openapi: false do
      let!(:sangaku) { create(:sangaku, title: "before_changed", user: user) }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "changed_title") }.to_json }
      let(:http_request) { patch api_v1_user_code_sangaku_path(sangaku.id), headers: { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' }, params: }

      it "return 401 errors" do
        http_request

        expect(response).to have_http_status(401)
        expect(sangaku.reload.title).to eq "before_changed"
      end
    end

    context "with invalid params", openapi: false do
      let!(:sangaku) { create(:sangaku, title: "before_changed", user: user) }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "") }.to_json }
      let(:http_request) { patch api_v1_user_code_sangaku_path(sangaku.id), headers:, params: }

      it "return 400 errors" do
        authenticate_stub(user)

        http_request

        expect(response).to have_http_status(400)
        expect(sangaku.reload.title).to eq "before_changed"
      end
    end

    # front は項目ごとのエラー表示に errors のキー名を使っているため、
    # delegated_type 移行後もキー名が変わらないことを固定する特性テスト（issue #278）。
    describe "error keys in the 400 response" do
      let!(:sangaku) { create(:sangaku, title: "before_changed", user: user) }
      let(:error_keys) { body["errors"].map(&:first) }
      let(:http_request) { patch api_v1_user_code_sangaku_path(sangaku.id), headers:, params: }

      before { authenticate_stub(user) }

      context "without a title", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, title: ""), fixed_inputs: [ "input_a" ] }.to_json }

        it "returns the title error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "title"
        end
      end

      context "without a description", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, description: ""), fixed_inputs: [ "input_a" ] }.to_json }

        it "returns the description error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "description"
        end
      end

      context "without a source", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params, source: ""), fixed_inputs: [ "input_a" ] }.to_json }

        it "returns the source error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "source"
        end
      end

      context "with duplicated fixed_inputs", openapi: false do
        let(:params) { { sangaku: attributes_for(:sangaku_params), fixed_inputs: [ "duplicated", "duplicated" ] }.to_json }

        it "returns the fixed_inputs error key" do
          http_request

          expect(response).to have_http_status(400)
          expect(error_keys).to include "fixed_inputs"
        end
      end
    end

    context "with anotheruser's sangaku id", openapi: false do
      let!(:another_user) { create(:user) }
      let!(:another_sangaku) { create(:sangaku, user: another_user) }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "changed_title") }.to_json }
      let(:http_request) { patch api_v1_user_code_sangaku_path(another_sangaku.id), headers:, params: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end

    context "removing a fixed_input that has answer_results", openapi: false do
      let!(:sangaku) { create(:sangaku, title: "before_changed", user: user) }
      let!(:fixed_input) { create(:fixed_input, sangaku: sangaku, content: "old_input") }
      # CodeAnswer#create_results が code_sangaku.fixed_inputs を参照するため、
      # user_sangaku_save/answer を作る前に関連キャッシュを更新しておく必要がある
      before { sangaku.reload }
      let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku: sangaku) }
      let!(:answer) { create(:answer, user_sangaku_save: user_sangaku_save) }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "changed_title"), fixed_inputs: [] }.to_json }
      let(:http_request) { patch api_v1_user_code_sangaku_path(sangaku.id), headers:, params: }

      it "success to update sangaku" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(FixedInput.exists?(fixed_input.id)).to eq false
      end
    end

    context "with a reorder_sangaku's id", openapi: false do
      let!(:reorder_sangaku) { create(:sangaku, :reorder, user: user) }
      let(:params) { { sangaku: attributes_for(:sangaku_params, title: "changed_title") }.to_json }
      let(:http_request) { patch api_v1_user_code_sangaku_path(reorder_sangaku.id), headers:, params: }

      it "return 404" do
        # set_code_sangaku の別形式ガード（sangaku.code_sangaku?）は実装済みだが、
        # 並べ替え形式の sangaku を作れなかったためこれまで検証できていなかった。
        # ReorderSangaku の追加により初めてテスト可能になった経路（新規のRED/GREENではなく特性テスト）
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end
  end

  describe "POST /api/v1/user/code_sangakus/generate_source" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:description) { "1からnまでの合計を計算して出力してください" }
    let(:params) { { description: description }.to_json }
    let(:http_request) { post generate_source_api_v1_user_code_sangakus_path, params: params, headers: headers }
    let(:generated_source) { "# 対応言語: Ruby\nn = gets.chomp.to_i\nputs (1..n).sum" }
    let(:openai_response) do
      {
        "choices" => [
          {
            "message" => {
              "content" => generated_source
            }
          }
        ]
      }
    end

    before do
      allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(openai_response)
    end

    context "with valid token" do
      it "returns generated source code with usage" do
        authenticate_stub(user)
        expect {
          http_request
        }.to change(GenerateSourceCallLog, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(body["source"]).to eq generated_source
        expect(body["usage"]["used"]).to eq 1
        expect(body["usage"]["limit"]).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT
        expect(body["usage"]["remaining"]).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT - 1
        expect(body["usage"]["reset_at"]).to be_present
      end

      it "calls OpenAI API with wrapped description" do
        authenticate_stub(user)
        expect_any_instance_of(OpenAI::Client).to receive(:chat).with(
          parameters: hash_including(
            messages: array_including(
              hash_including(role: "user", content: "---問題文開始---\n#{description}\n---問題文終了---")
            )
          )
        ).and_return(openai_response)
        http_request
      end
    end

    context "when daily limit is reached", openapi: false do
      before do
        User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT.times do
          create(:generate_source_call_log, user: user, called_at: Time.current)
        end
      end

      it "returns 429 without creating a log" do
        authenticate_stub(user)
        expect {
          http_request
        }.not_to change(GenerateSourceCallLog, :count)
        expect(response).to have_http_status(:too_many_requests)
        expect(body["errors"].first).to be_present
        expect(body["reset_at"]).to be_present
      end
    end

    context "when description exceeds max length", openapi: false do
      let(:description) { "a" * 2001 }

      it "returns 422 without calling OpenAI API and without creating a log" do
        authenticate_stub(user)
        expect_any_instance_of(OpenAI::Client).not_to receive(:chat)
        expect {
          http_request
        }.not_to change(GenerateSourceCallLog, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without token", openapi: false do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

      it "returns 401" do
        http_request
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when description is missing", openapi: false do
      let(:params) { {}.to_json }

      it "returns 400" do
        authenticate_stub(user)
        http_request
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when OpenAI API raises an error", openapi: false do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(OpenAI::Error)
      end

      it "returns 422 with an error message and still consumes the rate limit log" do
        authenticate_stub(user)
        expect {
          http_request
        }.to change(GenerateSourceCallLog, :count).by(1)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(body["error"]).to be_present
      end
    end

    context "when OpenAI API raises a network error", openapi: false do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(Faraday::TimeoutError)
      end

      it "returns 422 with an error message and still consumes the rate limit log" do
        authenticate_stub(user)
        expect {
          http_request
        }.to change(GenerateSourceCallLog, :count).by(1)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(body["error"]).to be_present
      end
    end

    context "JST 3:00 boundary behavior", openapi: false do
      it "counts logs only within the current JST day window" do
        authenticate_stub(user)
        travel_to Time.zone.local(2026, 4, 10, 2, 59, 59) do
          create(:generate_source_call_log, user: user, called_at: Time.current)
        end

        travel_to Time.zone.local(2026, 4, 10, 3, 0, 0) do
          http_request
          expect(response).to have_http_status(:ok)
          expect(body["usage"]["used"]).to eq 1
        end
      end
    end
  end

  describe "GET /api/v1/user/code_sangakus/generate_source_usage" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { get generate_source_usage_api_v1_user_code_sangakus_path, headers: headers }

    context "with valid token" do
      it "returns usage information" do
        authenticate_stub(user)
        http_request
        expect(response).to have_http_status(:ok)
        expect(body["used"]).to eq 0
        expect(body["limit"]).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT
        expect(body["remaining"]).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT
        expect(body["reset_at"]).to be_present
      end

      it "reflects existing call logs" do
        create(:generate_source_call_log, user: user, called_at: Time.current)
        authenticate_stub(user)
        http_request
        expect(response).to have_http_status(:ok)
        expect(body["used"]).to eq 1
        expect(body["remaining"]).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT - 1
      end

      it "does not count other users' logs" do
        another_user = create(:user)
        create(:generate_source_call_log, user: another_user, called_at: Time.current)
        authenticate_stub(user)
        http_request
        expect(response).to have_http_status(:ok)
        expect(body["used"]).to eq 0
      end
    end

    context "without token", openapi: false do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

      it "returns 401" do
        http_request
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
