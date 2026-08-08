class GenerateExpectedOutputJob < ApplicationJob
  include PaizaioApi

  queue_as :default

  def perform(fixed_input)
    result = run_source(fixed_input.sangaku.source, fixed_input.content)
    fixed_input.update_columns(expected_output: result["stdout"])
  rescue StandardError => e
    # PaizaIO 失敗時は nil のまま。採点時に都度実行するフォールバックに任せる
    Rails.logger.warn("[GenerateExpectedOutputJob] fixed_input_id=#{fixed_input.id} failed: #{e.class}: #{e.message}")
  end
end
