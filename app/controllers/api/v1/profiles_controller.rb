module Api
  module V1
    class ProfilesController < BaseController
      skip_before_action :authenticate

      def show
        user = ::User.find(params[:id])
        render json: ProfileSerializer.new(user).serializable_hash.to_json
      end
    end
  end
end
