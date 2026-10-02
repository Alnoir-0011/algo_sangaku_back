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

    it 'updates output to the stderr message and status to incorrect when the code raises a runtime error' do
      stub_paizaio_api(stderr: "NoMethodError: undefined method\n")

      CorrectnessCheckJob.perform_now(answer_result)
      expect(answer_result.reload.output).to eq("NoMethodError: undefined method\n")
      expect(answer_result.reload.status).to eq("incorrect")
    end

    context 'when update_status raises an error' do
      before do
        allow_any_instance_of(AnswerResult).to receive(:update_status).and_raise(StandardError, "PaizaIO error")
      end

      let(:job) { CorrectnessCheckJob.new }

      it 'sets status to error after exhausting retries' do
        allow(job).to receive(:executions).and_return(3)

        expect { job.perform(answer_result) }.to raise_error(StandardError)
        expect(answer_result.reload.status).to eq("error")
      end

      it 'logs an error after exhausting retries' do
        allow(job).to receive(:executions).and_return(3)

        expect(Rails.logger).to receive(:error) do |message|
          expect(message).to start_with("[CorrectnessCheckJob] answer_result_id=#{answer_result.id} failed:")
          expect(message).to include("StandardError", "PaizaIO error")
        end
        expect { job.perform(answer_result) }.to raise_error(StandardError)
      end

      it 'does not log or update status while retries remain' do
        allow(job).to receive(:executions).and_return(1)

        expect(Rails.logger).not_to receive(:error)
        expect { job.perform(answer_result) }.to raise_error(StandardError)
        expect(answer_result.reload.status).to eq("pending")
      end

      it 'does not log or update status on the second attempt' do
        allow(job).to receive(:executions).and_return(2)

        expect(Rails.logger).not_to receive(:error)
        expect { job.perform(answer_result) }.to raise_error(StandardError)
        expect(answer_result.reload.status).to eq("pending")
      end
    end
  end
end
