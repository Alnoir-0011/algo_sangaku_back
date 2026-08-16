require 'rails_helper'

RSpec.describe "Api::V1::BaseController", type: :request do
  # verify_client_secret は BaseController の before_action であり、
  # ShrinesController#index は authenticate を skip しているため、
  # このエンドポイントで verify_client_secret 単体の分岐を検証できる。
  describe "verify_client_secret" do
    let(:headers) { { CONTENT_TYPE: 'application/json', ACCEPT: 'application/json' } }
    let(:http_request) { get api_v1_shrines_path, headers: headers }

    before do
      allow(Settings).to receive(:verify_client_secret).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("CLIENT_SECRET").and_return("expected_secret")
    end

    context "when Settings.verify_client_secret is false" do
      before { allow(Settings).to receive(:verify_client_secret).and_return(false) }

      it "does not verify the client secret even without the header" do
        http_request

        expect(response).not_to have_http_status(403)
      end
    end

    context "when the X-Client-Secret header matches CLIENT_SECRET" do
      let(:http_request) { get api_v1_shrines_path, headers: headers.merge("X-Client-Secret" => "expected_secret") }

      it "passes verification and reaches the controller action" do
        http_request

        expect(response).not_to have_http_status(403)
      end
    end

    context "when the X-Client-Secret header does not match CLIENT_SECRET" do
      let(:http_request) { get api_v1_shrines_path, headers: headers.merge("X-Client-Secret" => "wrong_secret") }

      it "returns 403 Forbidden" do
        http_request

        expect(response).to have_http_status(403)
        expect(body['message']).to eq('Forbidden')
      end
    end

    context "when the X-Client-Secret header is missing" do
      it "returns 403 Forbidden" do
        http_request

        expect(response).to have_http_status(403)
        expect(body['message']).to eq('Forbidden')
      end
    end

    context "when CLIENT_SECRET is not configured" do
      before { allow(ENV).to receive(:[]).with("CLIENT_SECRET").and_return(nil) }

      let(:http_request) { get api_v1_shrines_path, headers: headers.merge("X-Client-Secret" => "expected_secret") }

      it "returns 403 Forbidden even when a header is sent" do
        http_request

        expect(response).to have_http_status(403)
        expect(body['message']).to eq('Forbidden')
      end
    end
  end
end
