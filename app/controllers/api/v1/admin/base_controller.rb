module Api
  module V1
    module Admin
      class BaseController < Api::V1::BaseController
        before_action :authorize_admin!

        private

        def authorize_admin!
          render_error(403, "Forbidden") unless current_user&.admin?
        end
      end
    end
  end
end
