module Api
  module V1
    class User::AnswerResultsController < BaseController
      def show
        answer_result = current_user.answer_results.find(params[:id])
        render json: AnswerResultSerializer.new(answer_result).serializable_hash.to_json, status: :ok
      end
    end
  end
end
