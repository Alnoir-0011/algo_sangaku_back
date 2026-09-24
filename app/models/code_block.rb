# 並べ替え形式の算額を構成するコードブロック（issue #278）。
# correct_position が nil のものは正解に含まれないダミーブロックを表す。
# 一意性は DB の unique index ([reorder_sangaku_id, correct_position]) で担保するため、
# ここでは uniqueness バリデーションを持たない。
class CodeBlock < ApplicationRecord
  belongs_to :reorder_sangaku

  MAX_CONTENT_LENGTH = 2000

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }
end
