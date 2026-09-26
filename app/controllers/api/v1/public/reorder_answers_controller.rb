module Api
  module V1
    module Public
      # 未ログインでも神社の代表並べ替え問題に解答できるようにする公開エンドポイント（issue #359）。
      # 判定結果のみ返し、Answer/AnswerResult には一切保存しない。
      class ReorderAnswersController < BaseController
        include Api::RepresentativeSangaku

        skip_before_action :authenticate, only: %i[create]

        wrap_parameters :answer, include: %i[block_ids]

        def create
          sangaku = Sangaku.find(params[:reorder_sangaku_id])
          # GET 側と同じ理由で、非代表算額へのアクセスも 404 に倒す（issue #359）。
          return render_404 unless representative?(sangaku)

          status = sangaku.sangakuable.judge(answer_params[:block_ids])
          return render_400(nil, { block_ids: [ "が不正です" ] }) if status.nil?

          render json: { status: }, status: :ok
        end

        private

        def answer_params
          params.require(:answer).permit(block_ids: [])
        end
      end
    end
  end
end
