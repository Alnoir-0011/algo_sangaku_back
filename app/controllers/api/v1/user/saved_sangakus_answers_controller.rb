module Api
  module V1
    class User::SavedSangakusAnswersController < BaseController
      wrap_parameters :answer

      def create
        if sangaku_save.answer.present?
          return render_error(409, "Conflict", "この算額にはすでに解答が存在します")
        end

        # 形式を明示して分岐する。どれにも当てはまらない形式に CodeAnswer を作らないようにするため
        sangaku = sangaku_save.sangaku
        if sangaku.code_sangaku?
          create_code_answer
        elsif sangaku.reorder_sangaku?
          create_reorder_answer
        else
          raise ActiveRecord::RecordNotFound
        end
      rescue Answer::AlreadyAnsweredError
        render_error(409, "Conflict", "この算額にはすでに解答が存在します")
      end

      def show
        answer = sangaku_save.answer || raise(ActiveRecord::RecordNotFound)
        render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
      end

      private

      def create_code_answer
        save_and_render_answer(CodeAnswer.new(source: answer_params[:source]))
      end

      def create_reorder_answer
        block_ids = answer_params[:block_ids]

        return render_400(nil, { block_ids: [ "が不正です" ] }) unless ReorderSangaku.valid_block_ids?(block_ids)

        result = sangaku_save.sangaku.sangakuable.correct?(block_ids) ? :correct : :incorrect
        save_and_render_answer(ReorderAnswer.new(result:))
      end

      # create_code_answer / create_reorder_answer 共通の保存・レンダリング処理。
      # 形式ごとの差異は呼び出し側で組み立てた answerable にのみ現れる。
      def save_and_render_answer(answerable)
        answer = sangaku_save.build_answer(answerable:)

        if answer.save
          render json: AnswerSerializer.new(answer).serializable_hash.to_json, status: :ok
        else
          render_400(nil, answerable.errors.messages.merge(answer.errors.messages))
        end
      end

      def sangaku_save
        @sangaku_save ||= current_user.user_sangaku_saves.find_by!(sangaku_id: params[:saved_sangaku_id])
      end

      def answer_params
        params.require(:answer).permit(:source, block_ids: [])
      end
    end
  end
end
