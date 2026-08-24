module Api
  module V1
    class User::AnswersController < BaseController
      def show
        answer = current_user.answers.find(params[:id])
        render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
      end
    end
  end
end
