require 'rails_helper'

RSpec.describe "Api::V1::User::Profiles", type: :request do
  describe "PATCH /update" do
    let!(:user) { create(:user) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { user: { nickname: "changed_name" } }.to_json }
    let(:http_request) { patch api_v1_user_profile_path, headers:, params: }

    context "with access_token" do
      it "return user in json format" do
        authenticate_stub(user)
        http_request

        expect(response).to have_http_status(:ok)
        expect(body["data"]["attributes"]["nickname"]).to eq "changed_name"
      end
    end
  end
end
