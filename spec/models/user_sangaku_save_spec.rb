require 'rails_helper'

RSpec.describe UserSangakuSave, type: :model do
  describe 'validation' do
    it 'is valid with all attributes' do
      user_sangaku_save = build(:user_sangaku_save)
      expect(user_sangaku_save).to be_valid
      expect(user_sangaku_save.errors).to be_empty
    end

    it 'is invalid when the same user saves the same sangaku twice' do
      user = create(:user)
      sangaku = create(:sangaku)
      create(:user_sangaku_save, user:, sangaku:)
      another_save = build(:user_sangaku_save, user:, sangaku:)

      expect(another_save).to be_invalid
      expect(another_save.errors[:sangaku_id]).to eq [ 'はすでに存在します' ]
    end

    it 'is valid when different users save the same sangaku' do
      sangaku = create(:sangaku)
      create(:user_sangaku_save, sangaku:)
      another_save = build(:user_sangaku_save, sangaku:)

      expect(another_save).to be_valid
      expect(another_save.errors).to be_empty
    end

    it 'is valid when the same user saves a different sangaku' do
      user = create(:user)
      create(:user_sangaku_save, user:)
      another_save = build(:user_sangaku_save, user:)

      expect(another_save).to be_valid
      expect(another_save.errors).to be_empty
    end

    it 'is invalid without a user' do
      user_sangaku_save = build(:user_sangaku_save, user: nil)

      expect(user_sangaku_save).to be_invalid
      expect(user_sangaku_save.errors[:user]).to be_present
    end

    it 'is invalid without a sangaku' do
      user_sangaku_save = build(:user_sangaku_save, sangaku: nil)

      expect(user_sangaku_save).to be_invalid
      expect(user_sangaku_save.errors[:sangaku]).to be_present
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      user_sangaku_save = build(:user_sangaku_save)
      expect(user_sangaku_save.user).to be_a(User)
    end

    it 'belongs to sangaku' do
      user_sangaku_save = build(:user_sangaku_save)
      expect(user_sangaku_save.sangaku).to be_a(Sangaku)
    end

    it 'has one answer' do
      user_sangaku_save = create(:user_sangaku_save)
      answer = create(:answer, user_sangaku_save:)

      expect(user_sangaku_save.reload.answer).to eq answer
    end
  end

  describe '#destroy' do
    it 'destroys the associated answer' do
      user_sangaku_save = create(:user_sangaku_save)
      answer = create(:answer, user_sangaku_save:)

      user_sangaku_save.destroy!

      expect(Answer.exists?(answer.id)).to eq false
    end
  end

  describe '.unanswered' do
    it 'returns saves without an answer and excludes saves with an answer' do
      unanswered_save = create(:user_sangaku_save)
      answered_save = create(:user_sangaku_save)
      create(:answer, user_sangaku_save: answered_save)

      expect(UserSangakuSave.unanswered).to include(unanswered_save)
      expect(UserSangakuSave.unanswered).not_to include(answered_save)
    end
  end

  describe '.answered' do
    it 'returns saves with an answer and excludes saves without an answer' do
      unanswered_save = create(:user_sangaku_save)
      answered_save = create(:user_sangaku_save)
      create(:answer, user_sangaku_save: answered_save)

      expect(UserSangakuSave.answered).to include(answered_save)
      expect(UserSangakuSave.answered).not_to include(unanswered_save)
    end
  end
end
