require 'rails_helper'

RSpec.describe CodeAnswer, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      code_answer = build(:code_answer)
      expect(code_answer).to be_valid
      expect(code_answer.errors).to be_empty
    end

    it "is invalid without source" do
      code_answer = build(:code_answer, source: "")
      expect(code_answer).to be_invalid
      expect(code_answer.errors[:source]).to eq [ "を入力してください" ]
    end
  end

  describe "#create_results" do
    let!(:sangaku) { create(:sangaku) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku:) }

    it "creates an AnswerResult for each fixed_input" do
      create(:fixed_input, sangaku:)
      create(:fixed_input, sangaku:)
      sangaku.reload

      answer = create(:answer, user_sangaku_save:)

      expect(answer.answerable.answer_results.count).to eq 2
    end

    it "creates a single AnswerResult without a fixed_input when the sangaku has none" do
      answer = create(:answer, user_sangaku_save:)

      expect(answer.answerable.answer_results.count).to eq 1
      expect(answer.answerable.answer_results.first.fixed_input).to be_nil
    end
  end

  describe "#status" do
    let!(:sangaku) { create(:sangaku) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku:) }
    let!(:fixed_input_1) { create(:fixed_input, sangaku:) }
    let!(:fixed_input_2) { create(:fixed_input, sangaku:) }
    let!(:answer) { create(:answer, user_sangaku_save: create(:user_sangaku_save, sangaku: sangaku.reload)) }
    let(:code_answer) { answer.answerable }

    it "returns pending when pending and error are both present" do
      code_answer.answer_results.first.update!(status: "error")
      code_answer.answer_results.second.update!(status: "pending")

      expect(code_answer.status).to eq "pending"
    end

    it "returns incorrect when incorrect and error are both present" do
      code_answer.answer_results.first.update!(status: "incorrect")
      code_answer.answer_results.second.update!(status: "error")

      expect(code_answer.status).to eq "incorrect"
    end

    it "returns correct when all answer_results are correct" do
      code_answer.answer_results.each { |result| result.update!(status: "correct") }

      expect(code_answer.status).to eq "correct"
    end
  end

  describe "status_correct / status_incorrect scopes" do
    let!(:sangaku) { create(:sangaku) }
    let!(:fixed_input) { create(:fixed_input, sangaku:) }
    let!(:answer) { create(:answer, user_sangaku_save: create(:user_sangaku_save, sangaku: sangaku.reload)) }
    let(:code_answer) { answer.answerable }

    it "matches status_correct when all results are correct" do
      code_answer.answer_results.each { |result| result.update!(status: "correct") }

      expect(CodeAnswer.status_correct).to include(code_answer)
      expect(CodeAnswer.status_incorrect).not_to include(code_answer)
    end

    it "matches status_incorrect when a result is incorrect" do
      code_answer.answer_results.each { |result| result.update!(status: "incorrect") }

      expect(CodeAnswer.status_incorrect).to include(code_answer)
      expect(CodeAnswer.status_correct).not_to include(code_answer)
    end

    it "matches neither scope when a result is still pending" do
      code_answer.answer_results.each { |result| result.update!(status: "pending") }

      expect(CodeAnswer.status_correct).not_to include(code_answer)
      expect(CodeAnswer.status_incorrect).not_to include(code_answer)
    end
  end
end
