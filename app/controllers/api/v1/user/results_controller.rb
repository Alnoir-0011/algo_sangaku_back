module Api
  module V1
    class User::ResultsController < BaseController
      def show
        sangaku = current_user.sangakus.find_by(id: params[:sangaku_id])

        user_sangaku_save_count = sangaku.user_sangaku_saves.count
        correct_count = sangaku.answers.is_status("correct").count
        incorrect_count = sangaku.answers.is_status("incorrect").count

        render json: {
          data: {
            attributes: {
              user_sangaku_save_count:,
              correct_count:,
              incorrect_count:
            }
          }
        }, status: :ok
      end
    end
  end
end
