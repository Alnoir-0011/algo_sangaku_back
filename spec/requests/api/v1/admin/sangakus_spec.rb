require 'rails_helper'

RSpec.describe "Api::V1::Admin::Sangakus", type: :request do
  let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
  let!(:admin_user) { create(:user, :admin) }
  let!(:general_user) { create(:user) }
  let!(:sangaku) { create(:sangaku, user: general_user) }

  describe "GET /api/v1/admin/sangakus" do
    context "as admin" do
      it "returns 200 with sangakus list" do
        authenticate_stub(admin_user)
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]).to be_an(Array)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_sangakus_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/admin/sangakus/:id" do
    context "as admin" do
      it "returns 200 with sangaku attributes" do
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs).to include("title", "description", "source", "difficulty", "created_at")
      end

      it "returns 404 for nonexistent sangaku", openapi: false do
        authenticate_stub(admin_user)
        get api_v1_admin_sangaku_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/admin/sangakus/:id" do
    let(:new_params) do
      {
        sangaku: {
          title: "更新タイトル",
          difficulty: "normal",
          description: "更新説明文",
          source: "puts 'updated'"
        }
      }
    end

    context "as admin" do
      it "returns 200 and updates the sangaku" do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: new_params.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs["title"]).to eq("更新タイトル")
        expect(attrs["difficulty"]).to eq("normal")
        expect(attrs["description"]).to eq("更新説明文")
        expect(attrs["source"]).to eq("puts 'updated'")
      end

      it "returns 400 when title is blank", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: { sangaku: { title: "" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when difficulty is invalid", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: { sangaku: { difficulty: "invalid_value" } }.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 for nonexistent sangaku", openapi: false do
        # Arrange
        authenticate_stub(admin_user)

        # Act
        patch api_v1_admin_sangaku_path(0),
              params: new_params.to_json,
              headers: headers

        # Assert
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: new_params.to_json,
              headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        patch api_v1_admin_sangaku_path(sangaku.id),
              params: new_params.to_json,
              headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/admin/sangakus/:id" do
    context "as admin" do
      it "returns 200 and deletes the sangaku" do
        authenticate_stub(admin_user)
        expect {
          delete api_v1_admin_sangaku_path(sangaku.id), headers: headers
        }.to change(Sangaku, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for nonexistent sangaku", openapi: false do
        authenticate_stub(admin_user)
        delete api_v1_admin_sangaku_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 200 and deletes the sangaku when a fixed_input has answer_results", openapi: false do
        fixed_input = create(:fixed_input, sangaku: sangaku)
        sangaku.reload
        user_sangaku_save = create(:user_sangaku_save, sangaku: sangaku)
        create(:answer, user_sangaku_save: user_sangaku_save)

        authenticate_stub(admin_user)
        expect {
          delete api_v1_admin_sangaku_path(sangaku.id), headers: headers
        }.to change(Sangaku, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(FixedInput.exists?(fixed_input.id)).to eq false
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        delete api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        delete api_v1_admin_sangaku_path(sangaku.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
