module Api
  module V1
    class User::SangakusController < BaseController
      def index
        sangakus = current_user.sangakus.search(search_params).includes(:fixed_inputs)
        render json: SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
      end

      private
        def search_params
          params.permit(:title, :shrine_id)
        end
    end
  end
end
