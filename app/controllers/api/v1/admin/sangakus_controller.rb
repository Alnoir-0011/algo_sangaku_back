module Api
  module V1
    module Admin
      class SangakusController < BaseController
        include Api::CodeBlocksParams

        before_action :set_sangaku, only: %i[show update destroy]

        def index
          # シリアライザが形式ごとのテーブル（description / difficulty / source）を読むため sangakuable も読み込む
          @pagy, sangakus = pagy(::Sangaku.all.includes(:user, :shrine, :sangakuable).order(:id))
          render json: ::Admin::SangakuSerializer.new(sangakus).serializable_hash.to_json, status: :ok
        end

        def show
          render json: ::Admin::SangakuDetailSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        end

        def update
          sangakuable = @sangaku.sangakuable
          parent = sangakuable.sangaku
          parent.assign_attributes(sangaku_params.slice(:title))
          sangakuable.assign_attributes(sangaku_params.slice(*sangakuable_attribute_names))

          saved =
            if reorder_code_blocks_given?
              return render_too_many_code_blocks if too_many_code_blocks?
              return render_malformed_code_blocks if malformed_code_blocks?

              sangakuable.save_with_code_blocks(code_blocks_params)
            else
              save_sangaku_without_code_blocks(parent, sangakuable)
            end

          if saved
            render json: ::Admin::SangakuDetailSerializer.new(parent.reload).serializable_hash.to_json, status: :ok
          else
            render_400(nil, parent.errors.full_messages + sangakuable.errors.full_messages)
          end
        end

        def destroy
          @sangaku.destroy!
          render json: ::Admin::SangakuDetailSerializer.new(@sangaku).serializable_hash.to_json, status: :ok
        end

        private

        def set_sangaku
          @sangaku = ::Sangaku.includes(:user, :shrine).find(params[:id])
        end

        def sangaku_params
          params.require(:sangaku).permit(:title, :difficulty, :description, :source)
        end

        # 形式に合わない項目（並べ替え形式の source など）は代入せず無視する（issue #278）。
        def sangakuable_attribute_names
          names = %i[description difficulty]
          names << :source if @sangaku.code_sangaku?
          names
        end

        # 並べ替え形式かつ code_blocks が送られている場合だけ、全置換を行う（issue #278）。
        # 送られていなければブロックは変えない。コード記述形式では code_blocks を無視する。
        def reorder_code_blocks_given?
          @sangaku.reorder_sangaku? && code_blocks_given?
        end

        def render_too_many_code_blocks
          render_400(nil, [ "code_blocksは#{ReorderSangaku::MAX_CODE_BLOCKS}個以内にしてください" ])
        end

        def render_malformed_code_blocks
          render_400(nil, [ "code_blocksの形式が不正です" ])
        end

        # code_blocks を伴わない通常の更新。バリデーションが通った場合のみ保存する（issue #278）。
        def save_sangaku_without_code_blocks(parent, sangakuable)
          return false unless parent.valid? && sangakuable.valid?

          ActiveRecord::Base.transaction do
            sangakuable.save!
            parent.save!
          end
          true
        end
      end
    end
  end
end
