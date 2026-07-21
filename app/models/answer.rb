class Answer < ApplicationRecord
  class AlreadyAnsweredError < StandardError; end

  after_create :create_results
  after_initialize :prevent_overwriting_existing_answer, if: :new_record?

  belongs_to :user_sangaku_save
  has_many :answer_results, dependent: :destroy

  validates :source, presence: true, length: { maximum: 65_535 }

  # 優先順位: pending（1件でもあれば） > incorrect（error を含む） > correct（全件correctのときのみ）
  # #status（Rubyでの単一Answer判定）と同じ優先順位を表現している。変更時は両方揃えること。
  # 整合性は spec/models/answer_spec.rb の特性テストで保証している。
  scope :status_correct, -> { where.not(id: AnswerResult.where.not(status: "correct").select(:answer_id)) }
  scope :status_incorrect, -> {
    where.not(id: AnswerResult.where(status: "pending").select(:answer_id))
      .where(id: AnswerResult.where.not(status: "correct").select(:answer_id))
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

  private

  def prevent_overwriting_existing_answer
    return unless user_sangaku_save_id
    return unless self.class.exists?(user_sangaku_save_id: user_sangaku_save_id)

    raise AlreadyAnsweredError, "この算額にはすでに解答が存在します"
  end

  def create_results
    inputs = user_sangaku_save.sangaku.fixed_inputs

    if inputs.present?
      inputs.map do |input|
        answer_results.create!(fixed_input: input)
      end
    else
      answer_results.create!(fixed_input: nil)
    end
  end
end
