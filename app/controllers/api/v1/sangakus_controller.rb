module Api
  module V1
    class SangakusController < BaseController
      def create
        sangaku = current_user.sangakus.new(sangaku_params)
        inputs = params[:fixed_inputs]&.map { |fixed_input| sangaku.fixed_inputs.new(content: fixed_input) }

        if sangaku.save_with_inputs(inputs)
          render json: SangakuSerializer.new(sangaku).serializable_hash.to_json, status: :ok
        else
          p sangaku.errors
          render_400(nil, sangaku.errors.full_messages)
        end
      end

      private

      def sangaku_params
        params.require(:sangaku).permit(:title, :description, :source, :difficulty)
      end
    end
  end
end
