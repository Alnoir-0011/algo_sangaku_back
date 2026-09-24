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
  # このシャッフルは ReorderSangaku#save_with_code_blocks の INSERT 前のシャッフルと対になっている。
  # 保存側だけだと毎回同じ並びを返すため並びを覚えられ、こちら側だけだと id の昇順が正解順のままになる。
  # 片方だけ外すと正解順が推測できるため、どちらも必要（issue #278）。
  #
  # 解答済みの場合は、その人は既に解き終えていてネタバレにならないため、正解順で
  # correct_position 込みで返す。並べ替え形式は提出した並びを保存しないため、解答結果の画面は
  # これを使って正解コードを組み立てる（issue #92）。
  # コード記述形式には code_blocks が存在しないため空配列を返す。
  attribute :code_blocks do |sangaku, params|
    next [] unless sangaku.reorder_sangaku?

    viewer = params[:current_user]
    # params は自由形式のハッシュで、ここに入る値の型は呼び出し側任せになる。
    # 認可の判断材料のため、User 以外が渡されたら黙って伏せずに落とし、
    # 「誤った相手を渡している」実装ミスを本番より先に見つける（issue #92）。
    raise ArgumentError, "current_user must be a User" unless viewer.nil? || viewer.is_a?(User)

    blocks = sangaku.sangakuable.code_blocks.to_a

    if reveal_correct_order?(sangaku, viewer)
      ReorderSangaku.ordered_code_blocks_payload(blocks)
    else
      blocks.shuffle(random: SecureRandom).map { |block| { id: block.id, content: block.content } }
    end
  end

  # 正解順を見せてよい相手か。current_user が渡らない経路では伏せる側に倒す。
  # 作者は作者向けの詳細（SangakuDetailSerializer）で既に全て見られるため、ここでも見せる。
  def self.reveal_correct_order?(sangaku, viewer)
    return false if viewer.nil?

    sangaku.user_id == viewer.id || viewer.answered?(sangaku)
  end
end
