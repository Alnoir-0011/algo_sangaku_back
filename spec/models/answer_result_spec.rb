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
  end
end
