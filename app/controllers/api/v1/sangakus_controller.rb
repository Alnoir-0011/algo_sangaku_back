module Api
  module V1
    class SangakusController < BaseController
      def show
        sangaku = Sangaku.find(params[:id])
        # 解答済みかどうかで code_blocks の見せ方が変わるため current_user を渡す（issue #92）
        render json: PublicSangakuDetailSerializer.new(sangaku, params: { current_user: }).serializable_hash.to_json, status: :ok
      end
    end
  end
end
