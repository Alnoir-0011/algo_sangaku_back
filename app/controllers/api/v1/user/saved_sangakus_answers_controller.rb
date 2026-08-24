module Api
  module V1
    class User::SavedSangakusAnswersController < BaseController
      wrap_parameters :answer

      def create
        if sangaku_save.answer.present?
          return render_error(409, "Conflict", "この算額にはすでに解答が存在します")
        end

        answer = sangaku_save.build_answer(answer_params)

        if answer.save
          render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
        else
          render_400(nil, answer.errors.messages)
        end
      rescue Answer::AlreadyAnsweredError
        render_error(409, "Conflict", "この算額にはすでに解答が存在します")
      end

      def show
        answer = sangaku_save.answer || raise(ActiveRecord::RecordNotFound)
        render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
      end

      private

      def sangaku_save
        @sangaku_save ||= current_user.user_sangaku_saves.find_by!(sangaku_id: params[:saved_sangaku_id])
      end

      def answer_params
        params.require(:answer).permit(:source)
      end
    end
  end
end
