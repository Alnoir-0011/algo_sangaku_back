# コード記述形式の解答。テストケースごとに PaizaIO で実行した結果を answer_results に持つ（issue #278）。
class CodeAnswer < ApplicationRecord
  has_one :answer, as: :answerable, touch: true
  has_many :answer_results, dependent: :destroy

  validates :source, presence: true, length: { maximum: 65_535 }

  # 優先順位: pending（1件でもあれば） > incorrect（error を含む） > correct（全件correctのときのみ）
  # #status（Rubyでの単一Answer判定）と同じ優先順位を表現している。変更時は両方揃えること。
  # 整合性は spec/models/code_answer_spec.rb の特性テストで保証している。
  scope :status_correct, -> { where.not(id: AnswerResult.where.not(status: "correct").select(:code_answer_id)) }
  scope :status_incorrect, -> {
    where.not(id: AnswerResult.where(status: "pending").select(:code_answer_id))
      .where(id: AnswerResult.where.not(status: "correct").select(:code_answer_id))
  }

  # 優先順位: pending（1件でもあれば） > incorrect（error を含む） > correct（全件correctのときのみ）
  # scope :status_correct / :status_incorrect（集計用SQL版）と同じ優先順位を表現している。変更時は両方揃えること。
  def status
    statuses = answer_results.map(&:status)

    if statuses.include?("pending")
      "pending"
    elsif statuses.include?("incorrect") || statuses.include?("error")
      "incorrect"
    else
      "correct"
    end
  end

  # 親 Answer の after_create から、保存済みの親を受け取って呼ばれる。
  def create_results(answer)
    inputs = answer.user_sangaku_save.sangaku.sangakuable.fixed_inputs

    if inputs.present?
      inputs.map do |input|
        answer_results.create!(fixed_input: input)
      end
    else
      answer_results.create!(fixed_input: nil)
    end
  end
end
