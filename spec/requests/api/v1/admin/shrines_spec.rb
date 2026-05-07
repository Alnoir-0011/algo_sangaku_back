require 'rails_helper'

RSpec.describe "Api::V1::Admin::Shrines", type: :request do
  let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
  let!(:admin_user) { create(:user, :admin) }
  let!(:general_user) { create(:user) }
  let!(:shrine) { create(:shrine) }

  let(:valid_shrine_params) do
    {
      shrine: {
        name: "新しい神社",
        address: "東京都千代田区1-1",
        latitude: 35.681236,
        longitude: 139.767125,
        place_id: "ChIJAAAAAAAAAAAARuMgFzkAAAAA"
      }
    }.to_json
  end

  describe "GET /api/v1/admin/shrines" do
    context "as admin" do
      it "returns 200 with shrines list" do
        authenticate_stub(admin_user)
        get api_v1_admin_shrines_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(body["data"]).to be_an(Array)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_shrines_path, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_shrines_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/admin/shrines/:id" do
    context "as admin" do
      it "returns 200 with shrine attributes" do
        authenticate_stub(admin_user)
        get api_v1_admin_shrine_path(shrine.id), headers: headers

        expect(response).to have_http_status(:ok)
        attrs = body["data"]["attributes"]
        expect(attrs).to include("name", "address", "sangaku_count")
      end

      it "returns 404 for nonexistent shrine", openapi: false do
        authenticate_stub(admin_user)
        get api_v1_admin_shrine_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        get api_v1_admin_shrine_path(shrine.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        get api_v1_admin_shrine_path(shrine.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/admin/shrines" do
    context "as admin" do
      it "returns 201 and creates shrine with valid params" do
        authenticate_stub(admin_user)
        expect {
          post api_v1_admin_shrines_path, params: valid_shrine_params, headers: headers
        }.to change(Shrine, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "returns 400 when latitude is out of range", openapi: false do
        # Arrange
        params = {
          shrine: {
            name: "神社", address: "住所", latitude: 91.0, longitude: 139.0,
            place_id: "invalid_lat_place"
          }
        }.to_json

        # Act
        authenticate_stub(admin_user)
        post api_v1_admin_shrines_path, params: params, headers: headers

        # Assert
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when latitude is below -90", openapi: false do
        params = {
          shrine: {
            name: "神社", address: "住所", latitude: -91.0, longitude: 139.0,
            place_id: "invalid_lat_place2"
          }
        }.to_json

        authenticate_stub(admin_user)
        post api_v1_admin_shrines_path, params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when longitude is out of range", openapi: false do
        params = {
          shrine: {
            name: "神社", address: "住所", latitude: 35.0, longitude: 181.0,
            place_id: "invalid_lng_place"
          }
        }.to_json

        authenticate_stub(admin_user)
        post api_v1_admin_shrines_path, params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when longitude is below -180", openapi: false do
        params = {
          shrine: {
            name: "神社", address: "住所", latitude: 35.0, longitude: -181.0,
            place_id: "invalid_lng_place2"
          }
        }.to_json

        authenticate_stub(admin_user)
        post api_v1_admin_shrines_path, params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        post api_v1_admin_shrines_path, params: valid_shrine_params, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        post api_v1_admin_shrines_path, params: valid_shrine_params, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/admin/shrines/:id" do
    let(:update_params) do
      { shrine: { name: "更新後の神社名" } }.to_json
    end

    context "as admin" do
      it "returns 200 and updates shrine" do
        authenticate_stub(admin_user)
        patch api_v1_admin_shrine_path(shrine.id), params: update_params, headers: headers

        expect(response).to have_http_status(:ok)
        expect(shrine.reload.name).to eq("更新後の神社名")
      end

      it "returns 400 when latitude is out of range", openapi: false do
        params = { shrine: { latitude: 91.0 } }.to_json

        authenticate_stub(admin_user)
        patch api_v1_admin_shrine_path(shrine.id), params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when longitude is out of range", openapi: false do
        params = { shrine: { longitude: 181.0 } }.to_json

        authenticate_stub(admin_user)
        patch api_v1_admin_shrine_path(shrine.id), params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 for nonexistent shrine", openapi: false do
        authenticate_stub(admin_user)
        patch api_v1_admin_shrine_path(0), params: update_params, headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        patch api_v1_admin_shrine_path(shrine.id), params: update_params, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        patch api_v1_admin_shrine_path(shrine.id), params: update_params, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/admin/shrines/:id" do
    context "as admin" do
      it "returns 200 and deletes shrine" do
        authenticate_stub(admin_user)
        expect {
          delete api_v1_admin_shrine_path(shrine.id), headers: headers
        }.to change(Shrine, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for nonexistent shrine", openapi: false do
        authenticate_stub(admin_user)
        delete api_v1_admin_shrine_path(0), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as general user" do
      it "returns 403" do
        authenticate_stub(general_user)
        delete api_v1_admin_shrine_path(shrine.id), headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated" do
      it "returns 401" do
        delete api_v1_admin_shrine_path(shrine.id), headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
