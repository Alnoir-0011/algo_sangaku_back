require 'rails_helper'

RSpec.describe "Api::V1::Users", type: :request do
  describe "Post /users" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

    context 'user not created' do
      let!(:params) { { user: attributes_for(:user) }.to_json }
      let(:http_request) { post api_v1_users_path, params: params, headers: headers }

      it 'returns user in json format' do
        expect { http_request }.to change(User, :count).by(1)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'user alredy created' do
      let!(:user) { create(:user) }
      let!(:params) { { user: user.attributes.compact.except("id") }.to_json }
      let(:http_request) { post api_v1_users_path, params: params, headers: headers }

      it "user does not create" do
        expect { http_request }.to change(User, :count).by(0)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
