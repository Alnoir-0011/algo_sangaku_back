module Api
  module V1
    class User::AnswersController < BaseController
      def create
        sangaku_save = current_user.user_sangaku_saves.find_by!(sangaku_id: params[:sangaku_id])
        answer = sangaku_save.build_answer(answer_params)

        if answer.save
          render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
        else
          render_400(nil, answer.errors.messages)
        end
      end

      def show
        answer = current_user.answers.find(params[:id])
        render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
      end

      private

      def answer_params
        params.require(:answer).permit(:source)
      end
    end
  end
end
