module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: %i[show update]

        def index
          @pagy, users = pagy(filtered_users.order(created_at: sort_direction))
          render json: ::Admin::UserSerializer.new(users).serializable_hash.to_json, status: :ok
        end

        def show
          render json: ::Admin::UserSerializer.new(@user).serializable_hash.to_json, status: :ok
        end

        def update
          if current_user == @user
            return render_400(nil, [ "自分自身のロールは変更できません" ])
          end

          if ::User.admin.count == 1 && @user.admin?
            return render_400(nil, [ "最後の管理者を降格することはできません" ])
          end

          new_role = params.dig(:user, :role).to_s
          unless ::User.roles.key?(new_role)
            return render_400(nil, [ "無効なロールです" ])
          end

          was_admin = @user.admin?
          @user.role = new_role

          if @user.save
            @user.api_keys.destroy_all if was_admin && @user.general?
            render json: ::Admin::UserSerializer.new(@user).serializable_hash.to_json, status: :ok
          else
            render_400(nil, @user.errors.full_messages)
          end
        end

        private

        def set_user
          @user = ::User.find(params[:id])
        end

        ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

        def filtered_users
          return ::User.all unless params[:query].present?

          ::User.search(params[:query].to_s)
        end

        def sort_direction
          ALLOWED_SORT_DIRECTIONS.include?(params[:sort]) ? params[:sort].to_sym : :desc
        end
      end
    end
  end
end
