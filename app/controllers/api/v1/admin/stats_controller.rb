module Api
  module V1
    module Admin
      class StatsController < BaseController
        def show
          render json: {
            data: {
              users_count: ::User.count,
              sangakus_count: ::Sangaku.count,
              shrines_count: ::Shrine.count,
              answers_count: ::Answer.count
            }
          }, status: :ok
        end
      end
    end
  end
end
