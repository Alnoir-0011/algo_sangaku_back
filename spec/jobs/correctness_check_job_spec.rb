require 'rails_helper'

RSpec.describe CorrectnessCheckJob, type: :job do
  let!(:answer_result) { create(:answer_result, output: nil, status: "pending") }

  describe '#perform' do
    it 'enqueues the job' do
      ActiveJob::Base.queue_adapter = :test
      CorrectnessCheckJob.perform_later(answer_result)
      expect(CorrectnessCheckJob).to have_been_enqueued
    end

    it 'updates output and status to correct when answer matches expected' do
      CorrectnessCheckJob.perform_now(answer_result)
      expect(answer_result.reload.output).to eq("Hello world\n")
      expect(answer_result.reload.status).to eq("correct")
    end

    it 'sets status to error after exhausting retries' do
      allow(answer_result).to receive(:update_status).and_raise(StandardError, "PaizaIO error")
      allow_any_instance_of(CorrectnessCheckJob).to receive(:executions).and_return(3)

      expect {
        CorrectnessCheckJob.perform_now(answer_result)
      }.to raise_error(StandardError)

      expect(answer_result.reload.status).to eq("error")
    end
  end
end
