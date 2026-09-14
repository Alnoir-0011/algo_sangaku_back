# 解答者向けの1件分のレスポンス（GET /sangakus/:id、GET /user/saved_sangakus/:id）用のシリアライザ。
# 一覧用の PublicSangakuSerializer と異なり、code_blocks を含む（issue #278）。
class PublicSangakuDetailSerializer
  include JSONAPI::Serializer
  include PublicSangakuSerializerAttributes

  # 解答者に正解順（correct_position）やダミーかどうかを見せないよう、id と content だけを返す。
  # 並びから正解順やダミーの有無を推測されないよう、correct_position で並べる・正解ブロックだけを
  # 取り出すといった処理はせず、読み込んだブロックをそのままシャッフルする。
  # 返すたびに並びが変わるよう、ReorderSangaku#save_with_code_blocks と同じく SecureRandom を使う。
  # コード記述形式には code_blocks が存在しないため空配列を返す。
  attribute :code_blocks do |sangaku|
    next [] unless sangaku.reorder_sangaku?

    blocks = sangaku.sangakuable.code_blocks.to_a.shuffle(random: SecureRandom)
    blocks.map { |block| { id: block.id, content: block.content } }
  end
end
