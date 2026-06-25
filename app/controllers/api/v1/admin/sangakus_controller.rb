module Api
  module V1
    module Admin
      class SangakusController < BaseController
        before_action :set_sangaku, only: %i[show update destroy]

        def index
          @pagy, sangakus = pagy(::Sangaku.all.includes(:user, :shrine).order(:id))
          render json: ::Admin::SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
        end

        def show
          render json: ::Admin::SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        end

        def update
          if @sangaku.update(sangaku_params)
            render json: ::Admin::SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
          else
            render_400(nil, @sangaku.errors.full_messages)
          end
        end

        def destroy
          @sangaku.destroy!
          render json: ::Admin::SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        end

        private

        def set_sangaku
          @sangaku = ::Sangaku.includes(:user, :shrine).find(params[:id])
        end

        def sangaku_params
          params.require(:sangaku).permit(:title, :difficulty, :description, :source)
        end
      end
    end
  end
end
