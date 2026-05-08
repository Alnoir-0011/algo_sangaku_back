module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: %i[show update]

        def index
          @pagy, users = pagy(::User.all)
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

          was_admin = @user.admin?

          if @user.update(user_params)
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

        def user_params
          params.require(:user).permit(:role)
        end
      end
    end
  end
end
