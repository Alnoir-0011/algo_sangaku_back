class FixedInput < ApplicationRecord
  include PaizaioApi

  belongs_to :sangaku

  has_many :answer_results

  validates :content, presence: true, length: { maximum: 65_535 }
  validates :content, uniqueness: { scope: :sangaku_id }

  after_commit :generate_expected_output, on: %i[create update]

  private

  def generate_expected_output
    result = run_source(sangaku.source, content)
    update_columns(expected_output: result["stdout"])
  rescue StandardError
    # PaizaIO 失敗時は nil のまま。採点時に都度実行するフォールバックに任せる
  end
end
