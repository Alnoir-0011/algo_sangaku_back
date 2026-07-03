require "rails_helper"

class ExceptionHandlerTestController < ActionController::API
  include Api::ExceptionHandler

  def boom
    raise StandardError, "boom error"
  end
end

RSpec.describe Api::ExceptionHandler, type: :request do
  before do
    Rails.application.routes.draw do
      get "exception_handler_test/boom", to: "exception_handler_test#boom"
    end
  end

  after do
    Rails.application.reload_routes!
  end

  it "StandardError 発生時に例外の内容をログに出力すること" do
    expect(Rails.logger).to receive(:error).with(a_string_including("boom error"))

    get "/exception_handler_test/boom"
  end

  it "StandardError 発生時に500を返すこと" do
    allow(Rails.logger).to receive(:error)

    get "/exception_handler_test/boom"

    expect(response).to have_http_status(:internal_server_error)
  end
end
