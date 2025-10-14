module Api
  module V1
    class User::ProfilesController < BaseController
      def update
        user = ::User.find(current_user.id)

        if user.update(user_params)
          render json: UserSerializer.new(user).serializable_hash.to_json
        else
          render_400(nil, user.errors.messages)
        end
      end

      private

      def user_params
        params.require(:user).permit(:nickname)
      end
    end
  end
end
