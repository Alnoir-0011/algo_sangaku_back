module Api
  module V1
    class User::SavedSangakusController < BaseController
      def index
        if params[:type] == "answered"
          saved_sangakus = current_user.saved_sangakus.left_joins(:answers).where.not(answers: { id: nil }).search(search_params).includes(:fixed_inputs, :user)
        elsif params[:type] == "before_answer"
          saved_sangakus = current_user.saved_sangakus.left_joins(:answers).where(answers: { id: nil }).search(search_params).includes(:fixed_inputs, :user)
        else
          saved_sangakus = current_user.saved_sangakus.inculdes(:fixed_inputs, :user)
        end
        render json: SangakuSerializer.new(saved_sangakus).serializable_hash.to_json
      end

      def show
        saved_sangaku = current_user.saved_sangakus.find(params[:id])
        render json: SangakuSerializer.new(saved_sangaku).serializable_hash.to_json
      end

      private

      def search_params
        params.permit(:title, :difficulty)
      end
    end
  end
end
