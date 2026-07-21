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

    it "raises ActiveRecord::RecordNotUnique when user_sangaku_save_id duplicates at the database level" do
      existing_answer = create(:answer)
      another_answer = Answer.new(source: "test")
      another_answer.user_sangaku_save_id = existing_answer.user_sangaku_save_id

      expect { another_answer.save }.to raise_error(ActiveRecord::RecordNotUnique)
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

  describe "status calculation" do
    let!(:author) { create(:user, nickname: "author") }
    let!(:shrine) { create(:shrine) }
    let!(:sangaku) { create(:sangaku, shrine:, user: author) }
    let!(:fixed_input_1) { create(:fixed_input, sangaku:) }
    let!(:fixed_input_2) { create(:fixed_input, sangaku:) }
    let!(:user_sangaku_save) { create(:user_sangaku_save, sangaku: sangaku.reload) }
    let!(:answer) { create(:answer, user_sangaku_save:) }

    describe "#status" do
      it "returns pending when pending and error are both present" do
        answer.answer_results.first.update!(status: "error")
        answer.answer_results.second.update!(status: "pending")

        expect(answer.status).to eq "pending"
      end

      it "returns incorrect when incorrect and error are both present" do
        answer.answer_results.first.update!(status: "incorrect")
        answer.answer_results.second.update!(status: "error")

        expect(answer.status).to eq "incorrect"
      end

      it "returns correct when all answer_results are correct" do
        answer.answer_results.each { |result| result.update!(status: "correct") }

        expect(answer.status).to eq "correct"
      end
    end

    describe "status_correct / status_incorrect scopes" do
      it "matches only correct when all results are correct" do
        answer.answer_results.each { |result| result.update!(status: "correct") }

        expect(Answer.status_correct).to include(answer)
        expect(Answer.status_incorrect).not_to include(answer)
      end

      it "matches only incorrect when incorrect and error are mixed without pending" do
        answer.answer_results.first.update!(status: "incorrect")
        answer.answer_results.second.update!(status: "error")

        expect(Answer.status_incorrect).to include(answer)
        expect(Answer.status_correct).not_to include(answer)
      end

      it "matches incorrect when all results are error" do
        answer.answer_results.each { |result| result.update!(status: "error") }

        expect(Answer.status_incorrect).to include(answer)
        expect(Answer.status_correct).not_to include(answer)
      end

      it "matches neither scope when all results are pending" do
        answer.answer_results.each { |result| result.update!(status: "pending") }

        expect(Answer.status_correct).not_to include(answer)
        expect(Answer.status_incorrect).not_to include(answer)
      end

      it "matches neither scope when pending and correct are mixed" do
        answer.answer_results.first.update!(status: "pending")
        answer.answer_results.second.update!(status: "correct")

        expect(Answer.status_correct).not_to include(answer)
        expect(Answer.status_incorrect).not_to include(answer)
      end
    end

    describe "consistency between #status and status_correct/status_incorrect scopes" do
      [
        { statuses: %w[pending pending],   expected: "pending" },
        { statuses: %w[pending correct],   expected: "pending" },
        { statuses: %w[pending error],     expected: "pending" },
        { statuses: %w[correct correct],   expected: "correct" },
        { statuses: %w[correct incorrect], expected: "incorrect" },
        { statuses: %w[correct error],     expected: "incorrect" },
        { statuses: %w[error error],       expected: "incorrect" }
      ].each do |c|
        it "#status と scope の該当が #{c[:statuses]} -> #{c[:expected]} で一致する" do
          answer.answer_results.zip(c[:statuses]).each { |result, status| result.update!(status:) }

          expect(answer.status).to eq c[:expected]
          expect(Answer.status_correct.include?(answer)).to eq(c[:expected] == "correct")
          expect(Answer.status_incorrect.include?(answer)).to eq(c[:expected] == "incorrect")
        end
      end
    end
  end
end
