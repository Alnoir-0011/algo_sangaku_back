require 'rails_helper'

RSpec.describe ReorderAnswer, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      reorder_answer = build(:reorder_answer)
      expect(reorder_answer).to be_valid
      expect(reorder_answer.errors).to be_empty
    end

    it "is invalid without result" do
      reorder_answer = build(:reorder_answer, result: nil)

      expect(reorder_answer).to be_invalid
      expect(reorder_answer.errors[:result]).to be_present
    end
  end

  describe "result enum" do
    it "responds to the prefixed correct predicate method" do
      reorder_answer = build(:reorder_answer, result: :correct)

      expect(reorder_answer.result_correct?).to eq true
      expect(reorder_answer.result_incorrect?).to eq false
    end

    it "responds to the prefixed incorrect predicate method" do
      reorder_answer = build(:reorder_answer, result: :incorrect)

      expect(reorder_answer.result_incorrect?).to eq true
      expect(reorder_answer.result_correct?).to eq false
    end
  end

  describe "#status" do
    it "returns correct when result is correct" do
      reorder_answer = build(:reorder_answer, result: :correct)

      expect(reorder_answer.status).to eq "correct"
    end

    it "returns incorrect when result is incorrect" do
      reorder_answer = build(:reorder_answer, result: :incorrect)

      expect(reorder_answer.status).to eq "incorrect"
    end
  end

  describe "status_correct / status_incorrect scopes" do
    it "matches status_correct only for a correct reorder_answer" do
      correct_answer = create(:reorder_answer, result: :correct)
      incorrect_answer = create(:reorder_answer, result: :incorrect)

      expect(ReorderAnswer.status_correct).to include(correct_answer)
      expect(ReorderAnswer.status_correct).not_to include(incorrect_answer)
    end

    it "matches status_incorrect only for an incorrect reorder_answer" do
      correct_answer = create(:reorder_answer, result: :correct)
      incorrect_answer = create(:reorder_answer, result: :incorrect)

      expect(ReorderAnswer.status_incorrect).to include(incorrect_answer)
      expect(ReorderAnswer.status_incorrect).not_to include(correct_answer)
    end
  end
end
