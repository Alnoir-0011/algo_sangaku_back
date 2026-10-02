class CorrectnessCheckJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(answer_result)
    return unless answer_result.status_pending?

    answer_result.update_status
  rescue StandardError => e
    if executions >= 3
      Rails.logger.error("[CorrectnessCheckJob] answer_result_id=#{answer_result.id} failed:\n#{e.full_message}")
      answer_result.update(status: :error)
    end
    raise
  end
end
