module Api
  module V1
    class SangakusController < BaseController
      def show
        sangaku = Sangaku.find(params[:id])
        render json: PublicSangakuSerializer.new(sangaku).serializable_hash.to_json, status: :ok
      end
    end
  end
end
