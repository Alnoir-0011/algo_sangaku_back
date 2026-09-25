module Api
  module V1
    module Public
      # 未ログインでも神社の代表並べ替え問題を閲覧できるようにする公開エンドポイント（issue #359）。
      class ReorderSangakusController < BaseController
        include Api::RepresentativeSangaku

        skip_before_action :authenticate, only: %i[show]

        def show
          sangaku = Sangaku.find(params[:id])
          # 代表算額以外を 403（アクセス権なし）にすると、未認証のまま「この id は
          # 存在する（が権限がない）／存在しない」を判別できてしまう。両方とも
          # 404 に倒すことで、算額IDの存在有無を推測できないようにする（issue #359）。
          return render_404 unless representative?(sangaku)

          # 閲覧のたびに応答が変わりうる（シャッフルし直す）ため、CDN 等に
          # キャッシュされると PublicSangakuDetailSerializer の「毎回シャッフルして
          # 正解順を推測されにくくする」設計が実質無効化される。
          response.headers["Cache-Control"] = "no-store"
          # current_user を渡さないため、PublicSangakuDetailSerializer は常に
          # correct_position を伏せてシャッフル済みの code_blocks を返す。
          render json: PublicSangakuDetailSerializer.new(sangaku).serializable_hash.to_json, status: :ok
        end
      end
    end
  end
end
