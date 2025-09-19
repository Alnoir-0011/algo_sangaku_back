module Api
  module V1
    class AuthenticatesController < BaseController
      require "googleauth"
      skip_before_action :authenticate, only: %i[create]

      def create
          payload = verify_idtoken
          user = ::User.find_by(provider: "google", uid: payload["sub"])

        if user
          set_token!(user)
          render json: UserSerializer.new(user).serializable_hash.to_json, status: :ok
        else
          user = ::User.new(provider: "google", uid: payload["sub"], email: payload["email"], name: payload["name"])

          if user.save
            set_token!(user)
            render json: UserSerializer.new(user).serializable_hash.to_json, status: :ok
          else
            render_400(nil, user.errors.full_messages)
          end
        end
      end

      def destroy
        token = request.headers["Authorization"].split(" ")[1]
        key = ApiKey.find_by(access_token: token)
        key.destroy!
        render json: { message: "signout successful" }.to_json, status: :ok
      end

      private

      def verify_idtoken
        google_client_id = ENV["GOOGLE_CLIENT_ID"]
        begin
          Google::Auth::IDTokens.verify_oidc(params[:token], aud: google_client_id)
        rescue StandardError => e
          render_400(nil, "invalid token")
        end
      end
    end
  end
end
