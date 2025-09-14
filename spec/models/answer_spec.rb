require 'rails_helper'

RSpec.describe Answer, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      answer = build(:answer)
      expect(answer).to be_valid
      expect(answer.errors).to be_empty
    end

    it "is invalid without source" do
      answer = build(:answer, source: "")
      expect(answer).to be_invalid
      expect(answer.errors[:source]).to eq [ "を入力してください" ]
    end
  end
end
