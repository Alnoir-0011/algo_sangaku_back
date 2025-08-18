module Api
  module V1
    class User::SangakusController < BaseController
      before_action :set_sangaku, only: %i[show update destroy]

      def index
        @pagy, sangakus = pagy(current_user.sangakus.search(search_params).includes(:fixed_inputs))
        render json: SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
      end

      def show
        render json: SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
      end

      def create
        @sangaku = current_user.sangakus.new(sangaku_params)

        if @sangaku.save_with_inputs(params[:fixed_inputs])
          render json: SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        else
          render_400(nil, @sangaku.errors.messages)
        end
      end

      def update
        @sangaku.assign_attributes(sangaku_params)

        if @sangaku.save_with_inputs(params[:fixed_inputs])
          sangaku = current_user.sangakus.find(params[:id])
          render json: SangakuSerializer.new(sangaku).serializable_hash.to_json, status: :ok
        else
          render_400(nil, @sangaku.errors.messages)
        end
      end

      def destroy
        @sangaku.destroy!
        render json: SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
      end

      private

      def search_params
        params.permit(:title, :shrine_id)
      end

      def set_sangaku
        @sangaku = current_user.sangakus.find(params[:id])
      end

      def sangaku_params
        params.require(:sangaku).permit(:title, :description, :source, :difficulty)
      end
    end
  end
end
