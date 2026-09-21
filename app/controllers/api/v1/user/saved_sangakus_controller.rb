module Api
  module V1
    class User::SavedSangakusController < BaseController
      # 保存一覧は保存日時の降順。同時刻は保存の id の降順で並びを確定させる（issue #278）
      SAVED_ORDER = "user_sangaku_saves.created_at DESC, user_sangaku_saves.id DESC".freeze

      def index
        @pagy, saved_sangakus = pagy(index_scope.includes(:user, :shrine, sangakuable: :fixed_inputs))
        render json: PublicSangakuSerializer.new(saved_sangakus).serializable_hash.to_json
      end

      def show
        saved_sangaku = show_scope.find(params[:id])
        # 解答済みかどうかで code_blocks の見せ方が変わるため current_user を渡す（issue #92）
        render json: PublicSangakuDetailSerializer.new(saved_sangaku, params: { current_user: }).serializable_hash.to_json
      end

      private

      def index_scope
        case params[:type]
        when "answered"
          sangakus_ordered_by_save(current_user.user_sangaku_saves.answered)
        when "before_answer"
          sangakus_ordered_by_save(current_user.user_sangaku_saves.unanswered)
        else
          current_user.saved_sangakus.with_kind(params[:kind]).order(Arel.sql(SAVED_ORDER))
        end
      end

      # 保存テーブルを結合し、保存日時の降順（同時刻は保存の id の降順）で並べる（issue #278）。
      # Sangaku.search は distinct を使うため、そのまま保存日時で並べると PostgreSQL の
      # "for SELECT DISTINCT, ORDER BY expressions must appear in select list" になる。
      # 検索条件は算額 id を返すサブクエリに入れ、distinct をサブクエリの中に閉じ込める。
      # 1 人のユーザーは同じ算額を 1 回しか保存できないため、結合しても行は重複しない。
      def sangakus_ordered_by_save(saves_scope)
        Sangaku.joins(:user_sangaku_saves)
               .where(user_sangaku_saves: { id: saves_scope.select(:id) })
               .where(id: Sangaku.search(search_params).select(:id))
               .order(Arel.sql(SAVED_ORDER))
      end

      def show_scope
        if params[:type] == "before_answer"
          Sangaku.where(id: current_user.user_sangaku_saves.unanswered.select(:sangaku_id))
        else
          current_user.saved_sangakus
        end
      end

      def search_params
        params.permit(:title, :difficulty, :kind)
      end
    end
  end
end
