require 'rails_helper'

RSpec.describe "Api::V1::User::Sangakus::Dedicate", type: :request do
  describe "POST /dedicate" do
    let!(:user) { create(:user) }
    let!(:sangaku) { create(:sangaku, user:, shrine: nil) }
    let!(:shrine) { create(:shrine) }
    let(:params) { {}.to_json }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:http_request) { post api_v1_user_sangaku_dedicate_path(sangaku.id), headers: headers, params: params }

    context "with access_token" do
      let(:params) { { shrine_id: shrine.id, lat: 35.70204829610801, lng: 139.76789333814216  }.to_json }

      it "return sangaku in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(shrine.sangakus, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
