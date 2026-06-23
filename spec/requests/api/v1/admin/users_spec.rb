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

      context "with query parameter" do
        let!(:matched_by_email) { create(:user, email: "search_target@example.com", nickname: "other") }
        let!(:matched_by_nickname) { create(:user, email: "other@example.com", nickname: "search_target_nick") }
        let!(:unmatched_user) { create(:user, email: "nomatch@example.com", nickname: "nomatch") }

        it "returns only users matching query by email" do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { query: "search_target@" }, headers: headers

          expect(response).to have_http_status(:ok)
          ids = body["data"].map { |u| u["id"] }
          expect(ids).to include(matched_by_email.id.to_s)
          expect(ids).not_to include(unmatched_user.id.to_s)
          expect(ids).not_to include(matched_by_nickname.id.to_s)
        end

        it "returns only users matching query by nickname", openapi: false do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { query: "search_target_nick" }, headers: headers

          expect(response).to have_http_status(:ok)
          ids = body["data"].map { |u| u["id"] }
          expect(ids).to include(matched_by_nickname.id.to_s)
          expect(ids).not_to include(unmatched_user.id.to_s)
        end

        it "is case-insensitive", openapi: false do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { query: "SEARCH_TARGET@" }, headers: headers

          expect(response).to have_http_status(:ok)
          ids = body["data"].map { |u| u["id"] }
          expect(ids).to include(matched_by_email.id.to_s)
        end

        it "returns empty array when no users match", openapi: false do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { query: "zzz_no_match_zzz" }, headers: headers

          expect(response).to have_http_status(:ok)
          expect(body["data"]).to be_empty
        end

        it "returns all users when query is blank", openapi: false do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { query: "" }, headers: headers

          expect(response).to have_http_status(:ok)
          expect(body["data"].size).to eq(::User.count)
        end
      end

      context "with sort parameter" do
        let!(:older_user) { create(:user, created_at: 2.days.ago) }
        let!(:newer_user) { create(:user, created_at: 1.day.ago) }

        it "returns users in descending order by default", openapi: false do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, headers: headers

          expect(response).to have_http_status(:ok)
          ids = body["data"].map { |u| u["id"].to_i }
          expect(ids.index(older_user.id)).to be > ids.index(newer_user.id)
        end

        it "returns users in descending order when sort=desc" do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { sort: "desc" }, headers: headers

          expect(response).to have_http_status(:ok)
          ids = body["data"].map { |u| u["id"].to_i }
          expect(ids.index(older_user.id)).to be > ids.index(newer_user.id)
        end

        it "returns users in ascending order when sort=asc", openapi: false do
          authenticate_stub(admin_user)
          get api_v1_admin_users_path, params: { sort: "asc" }, headers: headers

          expect(response).to have_http_status(:ok)
          ids = body["data"].map { |u| u["id"].to_i }
          expect(ids.index(older_user.id)).to be < ids.index(newer_user.id)
        end
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
