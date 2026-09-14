module Api
  module V1
    # 並べ替え形式に固有の作成・更新を扱う（issue #278）。
    # 一覧・詳細・削除・奉納は形式に依存しないため User::SangakusController に残す。
    class User::ReorderSangakusController < BaseController
      include Api::SangakuableForm
      include Api::CodeBlocksParams

      before_action :set_reorder_sangaku, only: %i[update]

      def create
        return render_too_many_code_blocks if too_many_code_blocks?

        reorder_sangaku = ReorderSangaku.new(sangakuable_params)
        reorder_sangaku.build_sangaku(parent_params.merge(user: current_user))

        if reorder_sangaku.save_with_code_blocks(code_blocks_params)
          render json: SangakuDetailSerializer.new(reorder_sangaku.sangaku).serializable_hash.to_json, status: :ok
        else
          render_400(nil, merged_errors(reorder_sangaku))
        end
      end

      def update
        return render_too_many_code_blocks if too_many_code_blocks?

        # has_one 側から辿った親に代入することで、save_with_code_blocks が同じインスタンスを保存できる
        @reorder_sangaku.sangaku.assign_attributes(parent_params)
        @reorder_sangaku.assign_attributes(sangakuable_params)

        if @reorder_sangaku.save_with_code_blocks(code_blocks_params)
          render json: SangakuDetailSerializer.new(@reorder_sangaku.sangaku.reload).serializable_hash.to_json, status: :ok
        else
          render_400(nil, merged_errors(@reorder_sangaku))
        end
      end

      private

      def set_reorder_sangaku
        @reorder_sangaku = find_own_sangakuable!(:reorder_sangaku)
      end

      def sangaku_params
        params.require(:sangaku).permit(:title, :description, :difficulty)
      end

      def render_too_many_code_blocks
        render_400(nil, { code_blocks: [ "は#{ReorderSangaku::MAX_CODE_BLOCKS}個以内にしてください" ] })
      end
    end
  end
end
