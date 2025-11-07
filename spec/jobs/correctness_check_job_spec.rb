require 'rails_helper'

RSpec.describe CorrectnessCheckJob, type: :job do
  # let!(:user) { create(:user) }
  # let!(:author) { create(:user, nickname: "author") }
  # let!(:shrine) { create(:shrine) }
  # let!(:sangaku) { create(:sangaku, shrine:, user: author) }
  # let!(:user_sangaku_save) { create(:user_sangaku_save, user:, sangaku:) }
  let!(:answer_result) { create(:answer_result, output: nil, status: "pending") }

  describe 'perform_later' do
    it 'enqueue job' do
      ActiveJob::Base.queue_adapter = :test
      CorrectnessCheckJob.perform_later(answer_result)
      expect(CorrectnessCheckJob).to have_been_enqueued
    end

    it 'check answer' do
      ActiveJob::Base.queue_adapter = :test
      expect {
        CorrectnessCheckJob.perform_now(answer_result)
      }.to change { answer_result.output }.from(nil).to("Hello world\n")
    end
  end
end
