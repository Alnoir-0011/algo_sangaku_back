module Api
  module V1
    class User::SangakuSavesController < BaseController
      def index
        saved_sangakus = current_user.saved_sangakus.search(search_params).includes(:fixed_inputs, :user)
        render json: SangakuSerializer.new(saved_sangakus).serializable_hash.to_json
      end

      private

      def search_params
        params.permit(:title, :difficulty)
      end
    end
  end
end
