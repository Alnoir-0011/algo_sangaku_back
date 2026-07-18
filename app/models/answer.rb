class Answer < ApplicationRecord
  class AlreadyAnsweredError < StandardError; end

  after_create :create_results
  after_initialize :prevent_overwriting_existing_answer, if: :new_record?

  belongs_to :user_sangaku_save
  has_many :answer_results, dependent: :destroy

  validates :source, presence: true, length: { maximum: 65_535 }
  validates :user_sangaku_save_id, uniqueness: true

  scope :is_status, ->(status) { where.not(id: AnswerResult.where.not(status:).select(:answer_id)) }

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
