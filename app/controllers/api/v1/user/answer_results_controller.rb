module Api
  module V1
    class User::AnswerResultsController < BaseController
      def show
        # AnswerResultSerializer の belongs_to :answer が code_answer 経由で親を引くため、
        # 1 件の取得で追加クエリが出る。結果ページはこれをポーリングするので先に読み込む。
        answer_result = current_user.answer_results.includes(code_answer: :answer).find(params[:id])
        render json: AnswerResultSerializer.new(answer_result).serializable_hash.to_json, status: :ok
      end
    end
  end
end
