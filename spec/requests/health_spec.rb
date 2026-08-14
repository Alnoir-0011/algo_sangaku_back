require 'rails_helper'

RSpec.describe "Health", type: :request, openapi: false do
  describe "GET /health" do
    it "returns ok when the database connection succeeds" do
      get "/health"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("status" => "ok")
    end

    it "returns service_unavailable and logs the error when the database connection fails" do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError, "connection lost")
      expect(Rails.logger).to receive(:error).with(a_string_including("connection lost"))

      get "/health"

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)).to eq("status" => "error")
    end
  end
end
