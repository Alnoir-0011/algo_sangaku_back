module Api
  module V1
    module Admin
      class SangakusController < BaseController
        before_action :set_sangaku, only: %i[show destroy]

        def index
          @pagy, sangakus = pagy(::Sangaku.all.includes(:user, :shrine))
          render json: ::Admin::SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
        end

        def show
          render json: ::Admin::SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        end

        def destroy
          @sangaku.destroy!
          render json: ::Admin::SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        end

        private

        def set_sangaku
          @sangaku = ::Sangaku.find(params[:id])
        end
      end
    end
  end
end
