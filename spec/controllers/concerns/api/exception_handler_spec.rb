require "rails_helper"

RSpec.describe Api::ExceptionHandler, type: :request, openapi: false do
  before do
    stub_const("ExceptionHandlerTestController", Class.new(ActionController::API) do
      include Api::ExceptionHandler

      def boom
        raise StandardError, "boom error"
      end

      def not_found
        raise ActiveRecord::RecordNotFound, "not found"
      end

      def parameter_missing
        raise ActionController::ParameterMissing, :required_param
      end

      def not_unique
        raise ActiveRecord::RecordNotUnique, "duplicate key"
      end

      def invalid
        raise ActiveRecord::RecordInvalid, User.new
      end

      def too_many_requests
        raise TooManyRequestsError.new(reset_at: Time.zone.local(2026, 1, 1, 3, 0, 0))
      end
    end)

    Rails.application.routes.draw do
      get "exception_handler_test/boom", to: "exception_handler_test#boom"
      get "exception_handler_test/not_found", to: "exception_handler_test#not_found"
      get "exception_handler_test/parameter_missing", to: "exception_handler_test#parameter_missing"
      get "exception_handler_test/not_unique", to: "exception_handler_test#not_unique"
      get "exception_handler_test/invalid", to: "exception_handler_test#invalid"
      get "exception_handler_test/too_many_requests", to: "exception_handler_test#too_many_requests"
    end
  end

  after do
    Rails.application.reload_routes!
  end

  it "logs the exception message when a StandardError occurs" do
    expect(Rails.logger).to receive(:error).with(a_string_including("boom error"))

    get "/exception_handler_test/boom"
  end

  it "returns 500 when a StandardError occurs" do
    allow(Rails.logger).to receive(:error)

    get "/exception_handler_test/boom"

    expect(response).to have_http_status(:internal_server_error)
  end

  it "does not include the exception detail in the response when running in production" do
    allow(Rails.logger).to receive(:error)
    allow(Rails.env).to receive(:production?).and_return(true)

    get "/exception_handler_test/boom"

    expect(JSON.parse(response.body)["errors"]).to eq []
  end

  it "includes the exception detail in the response when not running in production" do
    allow(Rails.logger).to receive(:error)

    get "/exception_handler_test/boom"

    expect(JSON.parse(response.body)["errors"]).to include("boom error")
  end

  it "returns 404 with the standard not-found message when ActiveRecord::RecordNotFound occurs" do
    get "/exception_handler_test/not_found"

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["message"]).to eq "Record Not Found"
  end

  # render_400 は render_500 と異なり production 環境でも exception&.message をそのまま返す
  # （detail をマスクしない）。このテストは現状の挙動を記録するものであり、
  # 「本番でも詳細を返してよい」という仕様保証ではない。マスク対応は issue #312 で追跡する。
  it "returns 400 with the missing parameter's message when ActionController::ParameterMissing occurs" do
    get "/exception_handler_test/parameter_missing"

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)["errors"]).to include(a_string_including("required_param"))
  end

  it "returns 409 with the standard conflict message when ActiveRecord::RecordNotUnique occurs" do
    get "/exception_handler_test/not_unique"

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)["message"]).to eq "Conflict"
  end

  it "returns 409 with the standard conflict message when ActiveRecord::RecordInvalid occurs" do
    get "/exception_handler_test/invalid"

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)["message"]).to eq "Conflict"
  end

  # render_429 も render_400 と同様、production 環境でも exception&.message をマスクしない（issue #312）。
  it "returns 429 and includes reset_at when TooManyRequestsError occurs" do
    get "/exception_handler_test/too_many_requests"

    expect(response).to have_http_status(:too_many_requests)
    expect(JSON.parse(response.body)["reset_at"]).to eq Time.zone.local(2026, 1, 1, 3, 0, 0).iso8601
  end
end
