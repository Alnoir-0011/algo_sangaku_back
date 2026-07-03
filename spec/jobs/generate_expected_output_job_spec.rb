require 'rails_helper'

RSpec.describe GenerateExpectedOutputJob, type: :job do
  let!(:fixed_input) { create(:fixed_input, expected_output: nil) }

  describe '#perform' do
    it 'enqueues the job' do
      ActiveJob::Base.queue_adapter = :test
      GenerateExpectedOutputJob.perform_later(fixed_input)
      expect(GenerateExpectedOutputJob).to have_been_enqueued
    end

    it 'updates expected_output when PaizaIO succeeds' do
      GenerateExpectedOutputJob.perform_now(fixed_input)
      expect(fixed_input.reload.expected_output).to eq("Hello world\n")
    end

    it 'leaves expected_output as nil when PaizaIO fails' do
      allow_any_instance_of(GenerateExpectedOutputJob).to receive(:run_source).and_raise(StandardError, "PaizaIO error")

      GenerateExpectedOutputJob.perform_now(fixed_input)
      expect(fixed_input.reload.expected_output).to be_nil
    end
  end
end
