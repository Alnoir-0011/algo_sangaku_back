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
  end

  describe "POST /user/sangakus" do
    context "with_accesstoken" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
      let(:params) { { sangaku: attributes_for(:sangaku), fixed_inputs: [ attributes_for(:fixed_input)[:content] ] } }
      let!(:user) { create(:user) }

      it "success to create sangaku" do
        authenticate_stub(user)

        # post api_v1_sangakus_path, headers: headers, params: params.to_json
        expect {
          post api_v1_user_sangakus_path, headers: headers, params: params.to_json
        }.to change(Sangaku, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
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
  end

  describe "PATCH /user/sangakus/[id]" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { {} }

    context "with_accesstoken" do
      let!(:sangaku) { create(:sangaku, title: "before_changed",  user: user) }
      let(:http_request) { patch api_v1_user_sangaku_path(sangaku.id), headers:, params: }
      let(:params) { { sangaku: attributes_for(:sangaku, title: "changed_title"), fixed_inputs: [ "a" ] }.to_json }

      it "success to update sangaku" do
        authenticate_stub(user)

        http_request
        expect(response).to have_http_status(:ok)
        expect(response).to be_successful
        expect(body["data"]["attributes"]["title"]).to eq "changed_title"
      end
    end

    context "with nonexistent id", openapi: false do
      let(:params) { { sangaku:  attributes_for(:sangaku, title: "changed_title")  }.to_json }
      let(:http_request) { patch api_v1_user_sangaku_path(1000000), headers:, params: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
      end
    end

    context "with anotheruser's sangaku id", openapi: false do
      let!(:another_user) { create(:user) }
      let!(:another_sangaku) { create(:sangaku, user: another_user) }
      let(:params) { { sangaku:  attributes_for(:sangaku, title: "changed_title") }.to_json }
      let(:http_request) { patch api_v1_user_sangaku_path(another_sangaku.id), headers:, params: }

      it "return 404" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:not_found)
        expect(response).not_to be_successful
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

  describe "POST /user/sangakus/generate_source" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:description) { "1からnまでの合計を計算して出力してください" }
    let(:params) { { description: description }.to_json }
    let(:http_request) { post generate_source_api_v1_user_sangakus_path, params: params, headers: headers }
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
        expect(body["error"]).to be_present
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

      it "returns 422 without creating a log" do
        authenticate_stub(user)
        expect {
          http_request
        }.not_to change(GenerateSourceCallLog, :count)
        expect(response).to have_http_status(:unprocessable_entity)
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

  describe "GET /user/sangakus/generate_source_usage" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let!(:user) { create(:user) }
    let(:http_request) { get generate_source_usage_api_v1_user_sangakus_path, headers: headers }

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
