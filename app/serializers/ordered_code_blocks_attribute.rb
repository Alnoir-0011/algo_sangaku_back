# SangakuDetailSerializer と Admin::SangakuDetailSerializer で共通する code_blocks 属性（issue #278）。
# 作者向け・管理画面向けはどちらも correct_position を含めて返してよいため共通化する。
# 解答者向け（PublicSangakuDetailSerializer）は correct_position やダミーの有無を隠す必要があるため対象外。
module OrderedCodeBlocksAttribute
  extend ActiveSupport::Concern

  included do
    # コード記述形式には code_blocks が存在しないため空配列を返す。
    # 並べ替え形式では、正解ブロック（correct_position が非 nil）を correct_position の昇順、
    # ダミー（nil）を id の昇順で並べる。1回の読み込みを Ruby 側で並べ替えることで、
    # クエリを増やさずに済む。
    attribute :code_blocks do |sangaku|
      next [] unless sangaku.reorder_sangaku?

      blocks = sangaku.sangakuable.code_blocks.to_a
      ordered_blocks = ReorderSangaku.ordered_code_blocks(blocks)

      ordered_blocks.map do |block|
        { id: block.id, content: block.content, correct_position: block.correct_position }
      end
    end
  end
end
