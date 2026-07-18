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

    it "is invalid when user_sangaku_save_id is already taken" do
      existing_answer = create(:answer)
      another_answer = Answer.new(source: "test")
      another_answer.user_sangaku_save_id = existing_answer.user_sangaku_save_id

      expect(another_answer).to be_invalid
      expect(another_answer.errors[:user_sangaku_save_id]).to eq [ "はすでに存在します" ]
    end
  end

  describe "preventing overwriting an existing answer" do
    let!(:user_sangaku_save) { create(:user_sangaku_save) }
    let!(:existing_answer) { create(:answer, user_sangaku_save:) }

    it "raises AlreadyAnsweredError when building another answer for the same user_sangaku_save" do
      expect {
        user_sangaku_save.build_answer(source: "new")
      }.to raise_error(Answer::AlreadyAnsweredError)
    end

    it "does not delete the existing answer" do
      expect {
        user_sangaku_save.build_answer(source: "new")
      }.to raise_error(Answer::AlreadyAnsweredError)

      expect(Answer.exists?(existing_answer.id)).to be true
    end
  end
end
