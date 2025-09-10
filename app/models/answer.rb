class Answer < ApplicationRecord
  after_create :create_results

  belongs_to :user_sangaku_save
  has_many :answer_results, dependent: :destroy

  validates :source, presence: true, length: { maximum: 65_535 }

  private

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
