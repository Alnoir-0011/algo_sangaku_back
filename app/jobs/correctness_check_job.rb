class CorrectnessCheckJob < ApplicationJob
  queue_as :default

  def perform(answer_result)
    return unless answer_result.status_pending?

    answer_result.update_status
  end
end
