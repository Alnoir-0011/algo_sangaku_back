module Api
  module V1
    # 出題形式に依存しない一覧・詳細・削除を扱う（issue #278）。
    # コード記述形式に固有の作成・更新・模範解答生成は User::CodeSangakusController へ移した。
    class User::SangakusController < BaseController
      before_action :set_sangaku, only: %i[show destroy]

      def index
        @pagy, sangakus = pagy(current_user.sangakus.search(search_params).order(:id).includes(:user, :shrine, sangakuable: :fixed_inputs))
        render json: SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
      end

      def show
        render json: SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
      end

      def destroy
        @sangaku.destroy!
        render json: SangakuSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
      end

      private

      def search_params
        params.permit(:title, :shrine_id, :difficulty)
      end

      def set_sangaku
        @sangaku = current_user.sangakus.find(params[:id])
      end
    end
  end
end
