class FixedInput < ApplicationRecord
  belongs_to :code_sangaku

  has_many :answer_results, dependent: :destroy

  validates :content, presence: true, length: { maximum: 65_535 }
  validates :content, uniqueness: { scope: :code_sangaku_id }

  after_commit :generate_expected_output, on: %i[create update]

  private

  def generate_expected_output
    GenerateExpectedOutputJob.perform_later(self)
  end
end
