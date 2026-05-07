require 'rails_helper'

RSpec.describe "Api::V1::Admin::Users", type: :request do
  let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
  let!(:admin_user) { create(:user, :admin) }
  let!(:general_user) { create(:user) }

  describe "GET /api/v1/admin/users" do
    context "as admin" do
      it "returns 200 with users list" do
        authenticate_stub(admin_user)
        get api_v1_admin_users_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]).to be_an(Array)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_users_path, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_users_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/admin/users/:id" do
    context "as admin" do
      it "returns 200 with user attributes" do
        authenticate_stub(admin_user)
        get api_v1_admin_user_path(general_user.id), headers: headers

        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs).to include(
          "name", "email", "nickname", "role", "created_at",
          "sangaku_count", "answer_count"
        )
      end

      it "returns 404 for nonexistent user", openapi: false do
        authenticate_stub(admin_user)
        get api_v1_admin_user_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_user_path(admin_user.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_user_path(general_user.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/admin/users/:id" do
    let(:target_user) { create(:user) }

    context "as admin" do
      it "returns 200 when changing another user's role to admin" do
        authenticate_stub(admin_user)
        patch api_v1_admin_user_path(target_user.id),
              params: { user: { role: "admin" } }.to_json,
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(target_user.reload.role).to eq("admin")
      end

      it "destroys all api_keys when role is changed to general" do
        # Arrange
        target_admin = create(:user, :admin)
        target_api_key = create(:api_key, user: target_admin)

        # Act
        authenticate_stub(admin_user)
        patch api_v1_admin_user_path(target_admin.id),
              params: { user: { role: "general" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        expect(target_admin.api_keys.reload).to be_empty
      end

      it "does not change name or email even if passed" do
        # Arrange
        original_name = target_user.name
        original_email = target_user.email

        # Act
        authenticate_stub(admin_user)
        patch api_v1_admin_user_path(target_user.id),
              params: { user: { role: "admin", name: "hacked", email: "hacked@example.com" } }.to_json,
              headers: headers

        # Assert
        expect(target_user.reload.name).to eq(original_name)
        expect(target_user.reload.email).to eq(original_email)
      end

      it "returns 400 when admin tries to change own role", openapi: false do
        # Arrange & Act
        authenticate_stub(admin_user)
        patch api_v1_admin_user_path(admin_user.id),
              params: { user: { role: "general" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when demoting the last admin", openapi: false do
        # Arrange: admin_user is the only admin
        authenticate_stub(admin_user)
        patch api_v1_admin_user_path(admin_user.id),
              params: { user: { role: "general" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 for nonexistent user", openapi: false do
        authenticate_stub(admin_user)
        patch api_v1_admin_user_path(0),
              params: { user: { role: "admin" } }.to_json,
              headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        patch api_v1_admin_user_path(target_user.id),
              params: { user: { role: "admin" } }.to_json,
              headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        patch api_v1_admin_user_path(target_user.id),
              params: { user: { role: "admin" } }.to_json,
              headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
