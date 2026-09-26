module Api
  module V1
    module Public
      # front が「この神社のゲスト向け並べ替え問題」のIDを知るための入口（issue #359）。
      # front は Public::ReorderSangakusController / Public::ReorderAnswersController が
      # どの sangaku を対象にするかを、事前にこのエンドポイントで解決する想定。
      class RepresentativeReorderSangakusController < BaseController
        skip_before_action :authenticate, only: %i[show]

        def show
          shrine = Shrine.find(params[:shrine_id])
          sangaku = Sangaku.representative_reorder_for(shrine)
          return render_404 if sangaku.nil?

          # GET /public/reorder_sangakus/:id と同じ理由（閲覧のたびにシャッフルし直す）で
          # キャッシュさせない。
          response.headers["Cache-Control"] = "no-store"
          render json: PublicSangakuDetailSerializer.new(sangaku).serializable_hash.to_json, status: :ok
        end
      end
    end
  end
end
