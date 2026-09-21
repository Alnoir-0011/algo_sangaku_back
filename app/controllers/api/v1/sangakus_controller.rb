module Api
  module V1
    class SangakusController < BaseController
      def show
        sangaku = Sangaku.find(params[:id])
        # 同じ URL でも閲覧者ごとに中身（正解順を含むか）が変わるため、共有キャッシュに載せない
        response.headers["Cache-Control"] = "no-store"
        # 解答済みかどうかで code_blocks の見せ方が変わるため current_user を渡す（issue #92）
        render json: PublicSangakuDetailSerializer.new(sangaku, params: { current_user: }).serializable_hash.to_json, status: :ok
      end
    end
  end
end
