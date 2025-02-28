module Api
  module V1
    class UsersController < ApplicationController
      def create
        user = User.find_by(provider: params[:user][:provider], uid: params[:user][:uid])

        if user
          render json: UserSerializer.new(user).serializable_hash.to_json, status: :ok
        else
          user = User.new(user_params)
          user.initialize_nickname

          if user.save
            render json: UserSerializer.new(user).serializable_hash.to_json, status: :ok
          else
            render json: { error: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end


      private

      def user_params
        params.require(:user).permit(:provider, :uid, :name, :email)
      end
    end
  end
end
