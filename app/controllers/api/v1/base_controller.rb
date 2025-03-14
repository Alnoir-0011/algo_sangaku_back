module Api
  module V1
    class BaseController < ApplicationController
      require "net/http"
      require "googleauth"

      include Api::ExceptionHandler
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate

      protected

      def authenticate
        google_client_id = ENV["GOOGLE_CLIENT_ID"]

        authenticate_or_request_with_http_token do |token, _options|
          payload = Google::Auth::IDTokens.verify_oidc(token, aud: google_client_id)
          @_current_user = User.find_by(provider: "google", uid: payload["sub"])
        end
      end

      def current_user
        @_current_user
      end
    end
  end
end
