require 'rails_helper'

RSpec.describe "Api::V1::Admin::Stats", type: :request do
  let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
  let!(:admin_user) { create(:user, :admin) }
  let!(:general_user) { create(:user) }

  describe "GET /api/v1/admin/stats" do
    context "as admin" do
      it "returns 200 with aggregate counts" do
        # Arrange
        create_list(:user, 2)
        create_list(:sangaku, 3, user: general_user)
        create_list(:shrine, 2)

        # Act
        authenticate_stub(admin_user)
        get api_v1_admin_stats_path, headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        data = body["data"]
        expect(data).to include("users_count", "sangakus_count", "shrines_count", "answers_count")
        expect(data["users_count"]).to be_a(Integer)
        expect(data["sangakus_count"]).to be_a(Integer)
        expect(data["shrines_count"]).to be_a(Integer)
        expect(data["answers_count"]).to be_a(Integer)
      end

      it "reflects correct counts" do
        # Arrange: admin_user + general_user already created (2 users), add 1 more
        extra_user = create(:user)
        sangaku = create(:sangaku, user: extra_user)
        shrine = create(:shrine)

        # Act
        authenticate_stub(admin_user)
        get api_v1_admin_stats_path, headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        data = body["data"]
        expect(data["users_count"]).to eq(User.count)
        expect(data["sangakus_count"]).to eq(Sangaku.count)
        expect(data["shrines_count"]).to eq(Shrine.count)
        expect(data["answers_count"]).to eq(Answer.count)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_stats_path, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_stats_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
