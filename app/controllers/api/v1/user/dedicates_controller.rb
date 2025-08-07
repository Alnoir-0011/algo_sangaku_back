module Api
  module V1
    class User::DedicatesController < BaseController
      def create
        sangaku = current_user.sangakus.find(params[:sangaku_id])
        shrine = Shrine.find(params[:shrine_id])


        if sangaku.dedicate(shrine, params[:lat], params[:lng])
          render json: SangakuSerializer.new(sangaku).serializable_hash.to_json, status: :ok
        else
          render_400(nil, "算額を奉納できませんでした")
        end
      end
    end
  end
end
