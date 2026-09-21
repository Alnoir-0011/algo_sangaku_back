# 解答者向けの1件分のレスポンス（GET /sangakus/:id、GET /user/saved_sangakus/:id）用のシリアライザ。
# 一覧用の PublicSangakuSerializer と異なり、code_blocks を含む（issue #278）。
class PublicSangakuDetailSerializer
  include JSONAPI::Serializer
  include PublicSangakuSerializerAttributes

  # 未解答の解答者に正解順（correct_position）やダミーかどうかを見せないよう、id と content だけを返す。
  # 並びから正解順やダミーの有無を推測されないよう、correct_position で並べる・正解ブロックだけを
  # 取り出すといった処理はせず、読み込んだブロックをそのままシャッフルする。
  # 返すたびに並びが変わるよう、ReorderSangaku#save_with_code_blocks と同じく SecureRandom を使う。
  #
  # 解答済みの場合は、その人は既に解き終えていてネタバレにならないため、正解順で
  # correct_position 込みで返す。並べ替え形式は提出した並びを保存しないため、解答結果の画面は
  # これを使って正解コードを組み立てる（issue #92）。
  # コード記述形式には code_blocks が存在しないため空配列を返す。
  attribute :code_blocks do |sangaku, params|
    next [] unless sangaku.reorder_sangaku?

    blocks = sangaku.sangakuable.code_blocks.to_a

    if params[:current_user]&.answered?(sangaku)
      ReorderSangaku.ordered_code_blocks(blocks).map do |block|
        { id: block.id, content: block.content, correct_position: block.correct_position }
      end
    else
      blocks.shuffle(random: SecureRandom).map { |block| { id: block.id, content: block.content } }
    end
  end
end
