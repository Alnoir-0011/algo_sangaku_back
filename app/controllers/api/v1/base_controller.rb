module Api
  module V1
    class BaseController < ApplicationController
      include Api::ExceptionHandler
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate

      def set_token!(user)
        api_key = user.api_keys.create
        response.header["AccessToken"] = api_key.access_token
      end

      protected

      def authenticate
        authenticate_or_request_with_http_token do |token, _options|
          @_current_user ||= ApiKey.active.find_by(access_token: token)&.user
        end
      end

      def current_user
        @_current_user
      end
    end
  end
end
