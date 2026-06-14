class CorrectnessCheckJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(answer_result)
    return unless answer_result.status_pending?

    answer_result.update_status
  rescue StandardError
    answer_result.update(status: :error) if executions >= 3
    raise
  end
end
