class AnswerResult < ApplicationRecord
  include PaizaioApi

  after_commit :check_later, on: :create

  belongs_to :answer
  belongs_to :fixed_input, optional: true

  validates :output, length: { maximum: 65_535 }
  validates :fixed_input_id, uniqueness: { scope: :answer_id }

  enum :status, { pending: 0, correct: 10, incorrect: 20 }, prefix: true

  def update_status
    source = answer.source
    sangaku_source = answer.user_sangaku_save.sangaku.source
    input = fixed_input ? fixed_input.content : ""

    answer_result = run_source(source, input)
    correct_result = run_source(sangaku_source, input)

    new_status = "pending"
    output = ""

    if answer_result["stderror"].blank?
      new_status =  answer_result["stdout"] == correct_result["stdout"] ? "correct" : "incorrect"
      output = answer_result["stdout"]
    else
      new_status = "incorrect"
      output = answer_result["stderror"]
    end

    update!(status: new_status, output:)
  end

  private

  def check_later
    CorrectnessCheckJob.perform_later(self)
  end
end
