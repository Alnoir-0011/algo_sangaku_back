module Api
  module V1
    class User::SavedSangakusController < BaseController
      def index
        if params[:type] == "answered"
          @pagy, saved_sangakus = pagy(current_user.saved_sangakus.left_joins(:answers).where.not(answers: { id: nil }).search(search_params).includes(:fixed_inputs, :user))
          render json: SangakuSerializer.new(saved_sangakus).serializable_hash.to_json
        elsif params[:type] == "before_answer"
          @pagy, saved_sangakus = pagy(current_user.saved_sangakus.left_joins(:answers).where(answers: { id: nil }).search(search_params).includes(:fixed_inputs, :user))
          render json: SangakuSerializer.new(saved_sangakus).serializable_hash.to_json
        else
          @pagy, saved_sangakus = pagy(current_user.saved_sangakus.includes(:fixed_inputs, :user))
          render json: SangakuSerializer.new(saved_sangakus).serializable_hash.to_json
        end
      end

      def show
        if params[:type] == "before_answer"
          saved_sangaku = current_user.saved_sangakus.left_joins(:answers).where(answers: { id: nil }).find(params[:id])
          render json: SangakuSerializer.new(saved_sangaku).serializable_hash.to_json
        else
          saved_sangaku = current_user.saved_sangakus.find(params[:id])
          render json: SangakuSerializer.new(saved_sangaku).serializable_hash.to_json
        end
      end

      def answer
        answer = current_user.answers.joins(:user_sangaku_save).find_by!(user_sangaku_save: { sangaku_id: params[:id] })
        render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
      end

      private

      def search_params
        params.permit(:title, :difficulty)
      end
    end
  end
end
