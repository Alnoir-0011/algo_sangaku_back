require 'rails_helper'

RSpec.describe AnswerResult, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      answer_result = build(:answer_result)
      expect(answer_result).to be_valid
      expect(answer_result.errors).to be_empty
    end

    it "is valid without output" do
      answer_result = build(:answer_result, output: "")
      expect(answer_result).to be_valid
      expect(answer_result.errors).to be_empty
    end

    it "is invalid when the same fixed_input already has a result for the same answer" do
      answer = create(:answer)
      fixed_input = create(:fixed_input)
      create(:answer_result, answer:, fixed_input:)
      duplicate = build(:answer_result, answer:, fixed_input:)

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:fixed_input_id]).to be_present
    end

    it "is valid when the same fixed_input has results for different answers" do
      fixed_input = create(:fixed_input)
      create(:answer_result, fixed_input:)
      another = build(:answer_result, fixed_input:)

      expect(another).to be_valid
      expect(another.errors).to be_empty
    end
  end

  describe "#update_status" do
    let(:sangaku) { create(:sangaku) }
    let(:user_sangaku_save) { create(:user_sangaku_save, sangaku:) }
    let(:answer) { create(:answer, user_sangaku_save:) }

    before { allow(answer_result).to receive(:sleep) }

    context "when the fixed_input has an expected_output" do
      let(:fixed_input) { create(:fixed_input, sangaku:, expected_output: "Hello world\n") }
      let!(:answer_result) { create(:answer_result, answer:, fixed_input:, status: "pending", output: nil) }

      it "runs only the answer's source and uses the cached expected_output instead of re-running the sangaku source" do
        expect(answer_result).to receive(:run_source).once.with(answer.source, fixed_input.content).and_call_original

        answer_result.update_status

        expect(answer_result.reload.status).to eq "correct"
        expect(answer_result.reload.output).to eq "Hello world\n"
      end
    end

    context "when the fixed_input has no expected_output" do
      let(:fixed_input) { create(:fixed_input, sangaku:, expected_output: nil) }
      let!(:answer_result) { create(:answer_result, answer:, fixed_input:, status: "pending", output: nil) }

      it "runs the answer's source and then the sangaku's source to determine the expected output" do
        expect(answer_result).to receive(:run_source).with(answer.source, fixed_input.content).ordered.and_call_original
        expect(answer_result).to receive(:run_source).with(sangaku.source, fixed_input.content).ordered.and_call_original

        answer_result.update_status

        expect(answer_result.reload.status).to eq "correct"
      end
    end

    context "when there is no fixed_input" do
      # sangaku に fixed_input がないため、Answer#create_results により fixed_input: nil の
      # answer_result が既に1件自動生成されている（uniqueness制約のため二重に作成できない）
      let!(:answer_result) { answer.answer_results.first }

      it "runs the answer's source and then the sangaku's source with an empty input" do
        expect(answer_result).to receive(:run_source).with(answer.source, "").ordered.and_call_original
        expect(answer_result).to receive(:run_source).with(sangaku.source, "").ordered.and_call_original

        answer_result.update_status

        expect(answer_result.reload.status).to eq "correct"
      end
    end

    context "when the paizaio response includes stderr" do
      let(:fixed_input) { create(:fixed_input, sangaku:, expected_output: "Hello world\n") }
      let!(:answer_result) { create(:answer_result, answer:, fixed_input:, status: "pending", output: nil) }

      it "marks the result incorrect and stores the stderr as the output" do
        stub_paizaio_api(stderr: "NoMethodError: undefined method\n")

        answer_result.update_status

        expect(answer_result.reload.status).to eq "incorrect"
        expect(answer_result.reload.output).to eq "NoMethodError: undefined method\n"
      end
    end

    context "when the stdout does not match the expected output" do
      let(:fixed_input) { create(:fixed_input, sangaku:, expected_output: "different output\n") }
      let!(:answer_result) { create(:answer_result, answer:, fixed_input:, status: "pending", output: nil) }

      it "marks the result incorrect and stores the actual stdout as the output" do
        answer_result.update_status

        expect(answer_result.reload.status).to eq "incorrect"
        expect(answer_result.reload.output).to eq "Hello world\n"
      end
    end
  end

  describe "#check_later" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "enqueues a CorrectnessCheckJob after create" do
      # answer_result factory の answer association が Answer#create_results を発火させ、
      # sangaku に fixed_inputs が無いため fixed_input: nil の answer_result が追加で1件作られる。
      # そのため check_later は合計2回呼ばれる。
      expect { create(:answer_result) }.to have_enqueued_job(CorrectnessCheckJob).exactly(2).times
    end

    it "does not enqueue a CorrectnessCheckJob on update" do
      answer_result = create(:answer_result)

      expect { answer_result.update!(status: "correct") }.not_to have_enqueued_job(CorrectnessCheckJob)
    end
  end
end
