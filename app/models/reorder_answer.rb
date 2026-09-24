# 並べ替え形式の解答。提出物は保存せず、判定結果（result）のみを持つ（issue #278）。
class ReorderAnswer < ApplicationRecord
  has_one :answer, as: :answerable, touch: true

  enum :result, { correct: 0, incorrect: 1 }, prefix: true

  validates :result, presence: true

  scope :status_correct, -> { where(result: :correct) }
  scope :status_incorrect, -> { where(result: :incorrect) }

  def status
    result
  end
end
