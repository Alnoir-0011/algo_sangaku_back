module Api
  module V1
    class BaseController < ApplicationController
      include Api::ExceptionHandler
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pagy::Method

      before_action :verify_client_secret
      before_action :authenticate
      after_action { response.headers.merge!(@pagy.headers_hash) if @pagy }

      def set_token!(user)
        api_key = user.api_keys.create
        response.header["AccessToken"] = api_key.access_token
      end

      protected

      def verify_client_secret
        return if Rails.env.test?

        expected = ENV["CLIENT_SECRET"]
        actual = request.headers["X-Client-Secret"]

        unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, actual.to_s)
          render_error(403, "Forbidden")
        end
      end

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
