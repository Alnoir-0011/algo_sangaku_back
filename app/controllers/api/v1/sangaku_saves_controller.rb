module Api
  module V1
    class SangakuSavesController < BaseController
      def create
        sangaku = Sangaku.find(params[:sangaku_id])

        current_user.add_saved_sangakus(sangaku)
        render json: SangakuSerializer.new(sangaku).serializable_hash.to_json
      end
    end
  end
end
