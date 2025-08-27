module Api
  module V1
    class ShrinesSangakusController < BaseController
      skip_before_action :authenticate, only: %i[index]

      def index
        shrine = Shrine.find(params[:shrine_id])
        @pagy, sangakus = pagy(shrine.sangakus.search(search_params).includes(:fixed_inputs))
        render json: SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
      end

      private

      def search_params
        params.permit(:title, :difficulty)
      end
    end
  end
end
