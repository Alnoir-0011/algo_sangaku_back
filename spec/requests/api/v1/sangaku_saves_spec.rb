require 'rails_helper'

RSpec.describe "Api::V1::Sangakus", type: :request do
  describe "POST /sangakus/[id]/save" do
    let!(:user) { create(:user) }
    let!(:sangaku) { create(:sangaku) }
    let(:http_request) { post api_v1_sangaku_save_path(sangaku.id), headers: }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }

    context "with access_token" do
      it "return sangaku in json format" do
        authenticate_stub(user)

        expect {
          http_request
        }.to change(user.saved_sangakus, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
