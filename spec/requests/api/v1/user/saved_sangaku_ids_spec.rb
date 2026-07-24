require 'rails_helper'

RSpec.describe "Api::V1::User::SavedSangakuIds", type: :request do
  describe "GET /index" do
    let!(:user) { create(:user) }
    let!(:author) { create(:user, nickname: "author") }
    let!(:sangaku_a) { create(:sangaku, user: author) }
    let!(:sangaku_b) { create(:sangaku, user: author) }
    let!(:sangaku_c) { create(:sangaku, user: author) }
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json', Authorization: "Bearer dummy_id_token" } }
    let(:params) { { sangaku_ids: [ sangaku_a.id, sangaku_b.id, sangaku_c.id ] } }
    let(:http_request) { get api_v1_user_saved_sangaku_ids_path, headers:, params: }

    context "with access_token" do
      context "when some of the requested sangakus are saved" do
        let!(:saved_relation) { create(:user_sangaku_save, sangaku: sangaku_a, user: user) }

        it "returns only the saved sangaku ids" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).to contain_exactly(sangaku_a.id)
        end
      end

      context "when all of the requested sangakus are saved", openapi: false do
        let!(:saved_relation_a) { create(:user_sangaku_save, sangaku: sangaku_a, user: user) }
        let!(:saved_relation_b) { create(:user_sangaku_save, sangaku: sangaku_b, user: user) }
        let(:params) { { sangaku_ids: [ sangaku_a.id, sangaku_b.id ] } }

        it "returns all requested sangaku ids" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).to contain_exactly(sangaku_a.id, sangaku_b.id)
        end
      end

      context "when none of the requested sangakus are saved", openapi: false do
        let(:params) { { sangaku_ids: [ sangaku_b.id, sangaku_c.id ] } }

        it "returns an empty array" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).to eq []
        end
      end

      context "when another user has saved the requested sangaku", openapi: false do
        let!(:other_user) { create(:user) }
        let!(:other_saved_relation) { create(:user_sangaku_save, sangaku: sangaku_b, user: other_user) }
        let(:params) { { sangaku_ids: [ sangaku_a.id, sangaku_b.id ] } }

        it "does not include the other user's saved sangaku" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).not_to include(sangaku_b.id)
        end
      end

      context "when sangaku_ids param is missing", openapi: false do
        let(:params) { {} }

        it "returns an empty array without error" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).to eq []
        end
      end

      context "when sangaku_ids includes a non-existent id", openapi: false do
        let!(:saved_relation) { create(:user_sangaku_save, sangaku: sangaku_a, user: user) }
        let(:params) { { sangaku_ids: [ sangaku_a.id, 999_999 ] } }

        it "silently ignores the non-existent id" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).to contain_exactly(sangaku_a.id)
        end
      end

      context "when sangaku_ids includes a non-numeric value", openapi: false do
        let!(:saved_relation) { create(:user_sangaku_save, sangaku: sangaku_a, user: user) }
        let(:params) { { sangaku_ids: [ sangaku_a.id, "abc" ] } }

        it "does not raise and returns only the valid saved id" do
          authenticate_stub(user)
          http_request

          expect(response).to have_http_status(:ok)
          expect(body["saved_sangaku_ids"]).to contain_exactly(sangaku_a.id)
        end
      end
    end

    context "without token", openapi: false do
      let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }

      it "returns 401" do
        http_request
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
