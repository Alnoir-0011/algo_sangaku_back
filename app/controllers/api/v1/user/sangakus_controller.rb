module Api
  module V1
    class User::SangakusController < BaseController
      before_action :set_sangaku, only: %i[show update destroy]

      def index
        @pagy, sangakus = pagy(current_user.sangakus.search(search_params).includes(:fixed_inputs, :user))
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

      def generate_source
        description = params.require(:description)

        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              {
                role: "system",
                content: <<~PROMPT
                  あなたはRubyプログラミングの専門家です。
                  与えられたアルゴリズム問題の問題文から、その問題を解くRubyコードを生成してください。
                  - 標準入力（STDIN）から値を読み取り、標準出力（STDOUT）に結果を出力するコードを書いてください
                  - コードの先頭に `# 対応言語: Ruby` というコメントを追加してください
                  - コードのみを返し、説明文やマークダウンのコードブロック記法（```）は含めないでください
                PROMPT
              },
              {
                role: "user",
                content: description
              }
            ],
            max_tokens: 1000
          }
        )

        source = response.dig("choices", 0, "message", "content")
        render json: { source: source }, status: :ok
      rescue OpenAI::Error => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def search_params
        params.permit(:title, :shrine_id, :difficulty)
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
