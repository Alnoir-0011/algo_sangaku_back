module Api
  module V1
    class User::SavedSangakuIdsController < BaseController
      MAX_SANGAKU_IDS = 100

      def index
        render json: { saved_sangaku_ids: saved_sangaku_ids }, status: :ok
      end

      private

      def saved_sangaku_ids
        current_user.user_sangaku_saves
                     .where(sangaku_id: requested_sangaku_ids)
                     .pluck(:sangaku_id)
      end

      def requested_sangaku_ids
        params.permit(sangaku_ids: []).fetch(:sangaku_ids, []).first(MAX_SANGAKU_IDS)
      end
    end
  end
end
