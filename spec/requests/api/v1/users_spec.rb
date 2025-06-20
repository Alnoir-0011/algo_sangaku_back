require 'rails_helper'

RSpec.describe "Api::V1::Users", type: :request do
  describe "Post /users" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:dummy_payload) { {} }

    before do
      allow_any_instance_of(Api::V1::UsersController).to receive(:verify_idtoken).and_return(dummy_payload)
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
      let(:http_request) { post api_v1_users_path, params: params, headers: headers }

      it 'returns user in json format' do
        expect { http_request }.to change(User, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.headers.keys).to include 'tokenexpires-at'
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
      let(:http_request) { post api_v1_users_path, params: params, headers: headers }

      it "user does not create" do
        expect { http_request }.to change(User, :count).by(0)
        expect(response).to have_http_status(:ok)
        expect(response.headers.keys).to include 'tokenexpires-at'
      end
    end
  end
end
