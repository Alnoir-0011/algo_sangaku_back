require 'rails_helper'

RSpec.describe "Api::V1::Sangakus", type: :request do
  describe "POST /sangakus" do
    context "with_accesstoken" do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
      let(:params) { { sangaku: attributes_for(:sangaku), fixed_inputs: [ attributes_for(:fixed_input)[:content] ] } }

      it "return sangaku in json format" do
        authenticate_stub

        # post api_v1_sangakus_path, headers: headers, params: params.to_json
        expect {
        post api_v1_sangakus_path, headers: headers, params: params.to_json
        }.to change(Sangaku, :count).by(1)
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
