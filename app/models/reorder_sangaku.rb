# 並べ替え形式の算額。コードブロックを正しい順序に並べ替えて回答する（issue #278）。
class ReorderSangaku < ApplicationRecord
  include Sangakuable

  MAX_CODE_BLOCKS = 100
  # code_blocks.id（bigint）の取りうる最大値。この範囲外の id は必ず該当レコードが
  # 存在しないため、DB に問い合わせる前に弾く（issue #359 セキュリティレビュー対応）。
  POSTGRES_BIGINT_MAX = 9_223_372_036_854_775_807

  has_many :code_blocks, dependent: :destroy

  # save_with_code_blocks に渡された送信順のブロック。エラーに送信順の位置を入れるために持つ。
  # INSERT 前にシャッフルするため、保存する側（code_blocks）の並びは送信順とは一致しない。
  attr_accessor :submitted_code_blocks

  validate :code_blocks_composition
  validate :submitted_code_blocks_contents

  # 解答で送られた block_ids の「形」が正しいかを判定する（中身の正誤は correct? で判定する）。
  # 形が不正な解答は判定せずに 400 とし、解答を消費させない。
  # 大量の要素を送られたときに無駄な計算をしないよう、件数を先に見てから要素を走査する。
  def self.valid_block_ids?(block_ids)
    block_ids.is_a?(Array) &&
      block_ids.present? &&
      block_ids.size <= MAX_CODE_BLOCKS &&
      block_ids.all? { |id| id.is_a?(Integer) && id.between?(1, POSTGRES_BIGINT_MAX) } &&
      block_ids.uniq.size == block_ids.size
  end

  # block_ids の形式を検証したうえで判定する。形式が不正なら nil を返し、呼び出し側で
  # 400 として扱う。検証と判定を1つの入り口にまとめることで、会員向け
  # （User::SavedSangakusAnswersController）とゲスト向け（Public::ReorderAnswersController）の
  # どちらかだけ検証や判定条件を直し忘れることを防ぐ（issue #359）。
  def judge(block_ids)
    return nil unless self.class.valid_block_ids?(block_ids)

    correct?(block_ids) ? :correct : :incorrect
  end

  # 親 sangaku・自身・code_blocks をまとめて保存する（全置換）。
  # delegated_type では子が先に INSERT される必要があるため、自身 → 親 の順に保存する。
  # id は連番で振られるため、correct_position 順のまま INSERT すると id の昇順だけで
  # 正解順が判明してしまう。それを防ぐため INSERT 順に shuffler を適用する。
  # 既定の shuffler は SecureRandom を使い、並び（＝ id の順）を予測されにくくする。
  # このシャッフルは PublicSangakuDetailSerializer が返すたびに行うシャッフルと対になっている。
  # こちら側だけだと毎回同じ並びを返すことになり、あちら側だけだと id の昇順が正解順のままになる。
  # 片方だけ外すと正解順が推測できるため、どちらも必要。
  def save_with_code_blocks(new_blocks, shuffler: ->(items) { items.shuffle(random: SecureRandom) })
    new_blocks ||= []
    self.submitted_code_blocks = new_blocks
    ordered_blocks = shuffler.call(new_blocks)

    ActiveRecord::Base.transaction do
      code_blocks.destroy_all
      ordered_blocks.each do |block|
        code_blocks.build(content: block[:content], correct_position: block[:correct_position])
      end

      # self（code_blocks の構成）が invalid だと save! がここで例外を送出し、
      # 後続の sangaku.save! に到達できない。そのままだと親の errors が一度も
      # 計算されず、コントローラの merged_errors から親のエラーキー（title など）が
      # 抜け落ちてしまう。save! の成否に関わらず親の errors を先に埋めておく。
      sangaku&.invalid?

      save!
      sangaku.save!
    end

    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  # 正解ブロック（correct_position が非nil）を correct_position の昇順、ダミー（nil）を id の昇順で
  # 並べる。作者向け（SangakuDetailSerializer）・管理画面向け（Admin::SangakuDetailSerializer）の
  # 詳細レスポンスで共通して使うロジックのため、ここに切り出す（issue #278）。
  def self.ordered_code_blocks(blocks)
    correct_blocks, dummy_blocks = blocks.partition { |block| block.correct_position.present? }
    correct_blocks.sort_by(&:correct_position) + dummy_blocks.sort_by(&:id)
  end

  # 正解順を見せてよい相手（作者・管理者・解答済みの本人）に返す code_blocks の形。
  # キー構成を 1 箇所にまとめ、返す項目を変えるときの直し漏れを防ぐ（issue #92）。
  def self.ordered_code_blocks_payload(blocks)
    ordered_code_blocks(blocks).map do |block|
      { id: block.id, content: block.content, correct_position: block.correct_position }
    end
  end

  # 与えられた block_ids の順序で並べた content 列が、正解順序（correct_position 昇順）の
  # content 列と一致するかを判定する。id ではなく content で比較することで、同一 content の
  # ブロックが複数あっても、どの id を使ったかに関わらず正しく判定できる。
  def correct?(block_ids)
    correct_contents = code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:content)
    contents_by_id = code_blocks.where(id: block_ids).pluck(:id, :content).to_h
    given_contents = block_ids.map { |id| contents_by_id[id] }

    correct_contents == given_contents
  end

  private

  def code_blocks_composition
    blocks = code_blocks.reject(&:marked_for_destruction?)

    if blocks.size > MAX_CODE_BLOCKS
      errors.add(:code_blocks, "は#{MAX_CODE_BLOCKS}個以内にしてください")
    end

    correct_positions = blocks.map(&:correct_position).compact.sort

    if correct_positions.size < 2
      errors.add(:code_blocks, "は正解ブロックを2個以上指定してください")
    elsif correct_positions != (1..correct_positions.size).to_a
      errors.add(:code_blocks, "の正解順序は1から始まる連番にしてください")
    end
  end

  # CodeBlock 側の検証だけだと、レスポンスは関連名に付く「は不正な値です」になり、
  # どのブロックが原因か分からない。送信順の位置と理由をエラーに足す。
  # 正解が画面やログに出ないよう、メッセージにブロックの内容そのものは含めない。
  # エラーのキーは front が項目の出し分けに使っているため :code_blocks のまま変えない（issue #278）。
  def submitted_code_blocks_contents
    return if submitted_code_blocks.blank?

    submitted_code_blocks.each_with_index do |block, index|
      content = block[:content]
      position = index + 1

      if content.blank?
        errors.add(:code_blocks, "の#{position}番目の内容を入力してください")
      elsif content.length > CodeBlock::MAX_CONTENT_LENGTH
        errors.add(:code_blocks, "の#{position}番目は#{CodeBlock::MAX_CONTENT_LENGTH}文字以内にしてください")
      end
    end
  end
end
