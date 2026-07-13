require 'rails_helper'

RSpec.describe "Api::V1::Authenticates", type: :request do
  describe "Post /create" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:dummy_payload) { {} }

    before do
      allow_any_instance_of(Api::V1::AuthenticatesController).to receive(:verify_idtoken).and_return(dummy_payload)
    end

    context 'with invalid token' do
      let!(:params) { { token: 'invalid_token' }.to_json }
      let(:http_request) { post api_v1_authenticate_path, params: params, headers: headers }

      before do
        allow_any_instance_of(Api::V1::AuthenticatesController).to receive(:verify_idtoken).and_return(nil)
      end

      it 'returns 400 bad request' do
        http_request
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'user not created' do
      let!(:params) { { token: 'dummy_idtoken' }.to_json }
      let!(:user_attr) { attributes_for(:user) }
      let!(:dummy_payload) { {
        "iss" => "https://accounts.google.com",
        "azp" => "dummy_azp",
        "aud" => "dummy_aud",
        "sub" => user_attr[:uid],
        "email" => user_attr[:email],
        "name" => user_attr[:name]
      } }
      let(:http_request) { post api_v1_authenticate_path, params: params, headers: headers }

      it 'returns user in json format' do
        expect { http_request }.to change(User, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.headers.keys).to include 'accesstoken'
      end

      it 'issues a raw token in the AccessToken header, not the stored digest' do
        # RED: base_controller#set_token! が api_key.access_token（ダイジェスト）を
        # そのままヘッダーに設定している現状の実装では、ヘッダー値と DB 上の access_token が
        # 一致してしまい、ダイジェストと不一致であることを検証するこのテストは失敗する
        http_request

        created_user = User.find_by(uid: user_attr[:uid])
        api_key = created_user.api_keys.last
        header_token = response.headers["AccessToken"]

        expect(header_token).to be_present
        expect(header_token).not_to eq(api_key.access_token)
        expect(ApiKey.digest(header_token)).to eq(api_key.access_token)
      end
    end

    context 'user alredy created' do
      let!(:user) { create(:user) }
      let!(:dummy_payload) { {
        "iss" => "https://accounts.google.com",
        "azp" => "dummy_azp",
        "aud" => "dummy_aud",
        "sub" => user.uid,
        "email" => user.email,
        "name" => user.name
      } }
      let!(:params) { { token: 'dummy_idtoken' }.to_json }
      let(:http_request) { post api_v1_authenticate_path, params: params, headers: headers }

      it "user does not create" do
        expect { http_request }.to change(User, :count).by(0)
        expect(response).to have_http_status(:ok)
        expect(response.headers.keys).to include 'accesstoken'
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:user) { create(:user) }
    let(:raw_token) { SecureRandom.uuid }
    let!(:api_key) { create(:api_key, user:, raw_token:) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:http_request) { delete api_v1_authenticate_path, headers: }

    context "with access_token" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer #{raw_token}" } }

      it 'return success message with json format' do
        # RED: authenticates_controller#destroy が Bearer トークンをダイジェスト化せずに
        # 生の access_token として find_by しているため、factory で raw_token からダイジェスト化した
        # access_token を保存している現状では、生トークンでの検索がヒットせず失敗する
        expect {
          http_request
        }.to change(ApiKey, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(body["message"]).to eq "signout successful"
      end
    end

    context "with an incorrect access_token" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer #{SecureRandom.uuid}" } }

      it 'does not delete any ApiKey' do
        # RED: 誤ったトークンでは該当レコードが見つからず削除されないことを保証する回帰テスト。
        # ダイジェスト化対応後の find_by ロジックが正しく「不一致」を判定できるかを検証する
        expect {
          http_request
        }.not_to change(ApiKey, :count)
      end
    end
  end
end
