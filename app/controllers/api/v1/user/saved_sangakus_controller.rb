module Api
  module V1
    class User::SavedSangakusController < BaseController
      def index
        @pagy, saved_sangakus = pagy(index_scope.includes(:fixed_inputs, :user, :shrine))
        render json: PublicSangakuSerializer.new(saved_sangakus).serializable_hash.to_json
      end

      def show
        saved_sangaku = show_scope.find(params[:id])
        render json: PublicSangakuSerializer.new(saved_sangaku).serializable_hash.to_json
      end

      def answer
        answer = current_user.answers.joins(:user_sangaku_save).find_by!(user_sangaku_save: { sangaku_id: params[:id] })
        render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
      end

      private

      def index_scope
        case params[:type]
        when "answered"
          Sangaku.where(id: current_user.user_sangaku_saves.answered.select(:sangaku_id)).search(search_params)
        when "before_answer"
          Sangaku.where(id: current_user.user_sangaku_saves.unanswered.select(:sangaku_id)).search(search_params)
        else
          current_user.saved_sangakus
        end
      end

      def show_scope
        if params[:type] == "before_answer"
          Sangaku.where(id: current_user.user_sangaku_saves.unanswered.select(:sangaku_id))
        else
          current_user.saved_sangakus
        end
      end

      def search_params
        params.permit(:title, :difficulty)
      end
    end
  end
end
