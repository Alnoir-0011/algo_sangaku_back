require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      user = build(:user)
      expect(user).to be_valid
      expect(user.errors).to be_empty
    end

    it "is invalid without provider" do
      user = build(:user, provider: '')
      expect(user).to be_invalid
      expect(user.errors[:provider]).to eq [ 'を入力してください' ]
    end

    it "is invalid without uid" do
      user = build(:user, uid: '')
      expect(user).to be_invalid
      expect(user.errors[:uid]).to eq [ 'を入力してください' ]
    end

    it "is invalid without name" do
      user = build(:user, name: '')
      expect(user).to be_invalid
      expect(user.errors[:name]).to eq [ 'を入力してください' ]
    end

    it "is invalid without email" do
      user = build(:user, email: '')
      expect(user).to be_invalid
      expect(user.errors[:email]).to eq [ 'を入力してください' ]
    end

    it "is invalid without nickname" do
      user = build(:user, nickname: '')
      expect(user).to be_invalid
      expect(user.errors[:nickname]).to eq [ 'を入力してください' ]
    end

    it "is valid with same provider" do
      user = create(:user)
      another_user = build(:user, provider: user.provider)
      expect(another_user).to be_valid
      expect(another_user.errors).to be_empty
    end

    it "is invalid with same uid" do
      new_uid = SecureRandom.uuid
      user = create(:user, uid: new_uid)
      another_user = build(:user, uid: new_uid)
      expect(another_user).to be_invalid
      expect(another_user.errors[:uid]).to eq [ 'はすでに存在します' ]
    end

    it "is valid with another uid" do
      create(:user)
      another_user = build(:user, uid: SecureRandom.uuid)
      expect(another_user).to be_valid
      expect(another_user.errors).to be_empty
    end

    it "is invalid with same email" do
      user = create(:user)
      another_user = build(:user, email: user.email)
      expect(another_user).to be_invalid
      expect(another_user.errors[:email]).to eq [ 'はすでに存在します' ]
    end

    it "is valid with another email" do
      create(:user)
      another_user = build(:user, email: "another_user@example.com")
      expect(another_user).to be_valid
      expect(another_user.errors).to be_empty
    end

    it "is valid with same name" do
      user = create(:user)
      another_user = build(:user, name: user.name)
      expect(another_user).to be_valid
      expect(another_user.errors).to be_empty
    end

    it "is valid with same nickname" do
      user = create(:user)
      another_user = build(:user, nickname: user.nickname)
      expect(another_user).to be_valid
      expect(another_user.errors).to be_empty
    end
  end

  describe "generate_source rate limit methods" do
    let(:user) { create(:user) }

    describe "#generate_source_daily_limit" do
      it "returns the default daily limit" do
        expect(user.generate_source_daily_limit).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT
      end
    end

    describe "#generate_source_daily_used_count" do
      context "when no logs exist" do
        it "returns 0" do
          expect(user.generate_source_daily_used_count).to eq 0
        end
      end

      context "when logs exist within the current day range" do
        before do
          travel_to Time.zone.local(2026, 4, 10, 10, 0, 0) do
            create(:generate_source_call_log, user: user, called_at: Time.current)
            create(:generate_source_call_log, user: user, called_at: Time.current - 1.hour)
          end
        end

        it "counts only logs within the current day range" do
          travel_to Time.zone.local(2026, 4, 10, 11, 0, 0) do
            expect(user.generate_source_daily_used_count).to eq 2
          end
        end
      end

      context "when logs exist outside the current day range" do
        before do
          create(:generate_source_call_log, user: user, called_at: Time.zone.local(2026, 4, 9, 10, 0, 0))
        end

        it "does not count logs from previous day" do
          travel_to Time.zone.local(2026, 4, 10, 10, 0, 0) do
            expect(user.generate_source_daily_used_count).to eq 0
          end
        end
      end
    end

    describe "#generate_source_daily_remaining" do
      context "when used count is below limit" do
        before do
          create(:generate_source_call_log, user: user, called_at: Time.current)
        end

        it "returns limit minus used count" do
          expect(user.generate_source_daily_remaining).to eq User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT - 1
        end
      end

      context "when used count equals limit" do
        before do
          User::GENERATE_SOURCE_DAILY_LIMIT_DEFAULT.times do
            create(:generate_source_call_log, user: user, called_at: Time.current)
          end
        end

        it "returns 0" do
          expect(user.generate_source_daily_remaining).to eq 0
        end
      end
    end

    describe "#generate_source_daily_reset_at" do
      it "returns the end of the current day range" do
        travel_to Time.zone.local(2026, 4, 10, 10, 0, 0) do
          expect(user.generate_source_daily_reset_at).to eq Time.zone.local(2026, 4, 11, 3, 0, 0)
        end
      end
    end
  end

  describe "#add_saved_sangakus" do
    it "adds the sangaku to the user's saved sangakus" do
      user = create(:user)
      sangaku = create(:sangaku)

      user.add_saved_sangakus(sangaku)

      expect(user.saved_sangakus).to include(sangaku)
    end
  end

  describe "#dedicated_sangakus_with_shrine" do
    it "returns only sangakus that have a shrine" do
      user = create(:user)
      shrine = create(:shrine)
      dedicated_sangaku = create(:sangaku, user:, shrine:)
      create(:sangaku, user:, shrine: nil)

      expect(user.dedicated_sangakus_with_shrine).to eq [ dedicated_sangaku ]
    end

    it "memoizes the result across calls" do
      user = create(:user)
      shrine = create(:shrine)
      create(:sangaku, user:, shrine:)

      first_call = user.dedicated_sangakus_with_shrine
      create(:sangaku, user:, shrine: create(:shrine))

      expect(user.dedicated_sangakus_with_shrine).to equal(first_call)
    end
  end

  describe "#destroy" do
    it "destroys the user's own reorder-format sangaku and their save/answer on another user's reorder-format sangaku without raising a foreign key violation, while leaving the other user's sangaku intact" do
      user = create(:user)
      other_user = create(:user)

      own_sangaku = create(:sangaku, :reorder, user:)
      own_sangakuable_id = own_sangaku.sangakuable.id
      own_code_block_ids = own_sangaku.sangakuable.code_blocks.pluck(:id)

      others_sangaku = create(:sangaku, :reorder, user: other_user)
      others_sangaku_id = others_sangaku.id
      others_sangakuable_id = others_sangaku.sangakuable.id

      user_sangaku_save = create(:user_sangaku_save, user:, sangaku: others_sangaku)
      answer = create(:answer, :reorder, user_sangaku_save:)

      user_id = user.id
      own_sangaku_id = own_sangaku.id
      user_sangaku_save_id = user_sangaku_save.id
      answer_id = answer.id
      reorder_answer_id = answer.answerable.id

      expect { user.destroy! }.not_to raise_error

      expect(User.exists?(user_id)).to eq false
      expect(Sangaku.exists?(own_sangaku_id)).to eq false
      expect(ReorderSangaku.exists?(own_sangakuable_id)).to eq false
      expect(CodeBlock.where(id: own_code_block_ids).exists?).to eq false
      expect(UserSangakuSave.exists?(user_sangaku_save_id)).to eq false
      expect(Answer.exists?(answer_id)).to eq false
      expect(ReorderAnswer.exists?(reorder_answer_id)).to eq false

      expect(Sangaku.exists?(others_sangaku_id)).to eq true
      expect(ReorderSangaku.exists?(others_sangakuable_id)).to eq true
    end

    it "destroys both a code-format sangaku and a reorder-format sangaku created by the user, along with their answers from another user, without raising a foreign key violation" do
      user = create(:user)
      other_user = create(:user)

      code_sangaku = create(:sangaku, user:)
      fixed_input = create(:fixed_input, sangaku: code_sangaku)
      code_sangaku.reload
      reorder_sangaku = create(:sangaku, :reorder, user:)
      reorder_code_block_ids = reorder_sangaku.sangakuable.code_blocks.pluck(:id)

      code_save = create(:user_sangaku_save, user: other_user, sangaku: code_sangaku)
      code_answer = create(:answer, user_sangaku_save: code_save)
      answer_result_ids = AnswerResult.where(code_answer: code_answer.answerable).pluck(:id)

      reorder_save = create(:user_sangaku_save, user: other_user, sangaku: reorder_sangaku)
      reorder_answer = create(:answer, :reorder, user_sangaku_save: reorder_save)

      code_sangaku_id = code_sangaku.id
      code_sangakuable_id = code_sangaku.sangakuable.id
      fixed_input_id = fixed_input.id
      reorder_sangaku_id = reorder_sangaku.id
      reorder_sangakuable_id = reorder_sangaku.sangakuable.id
      code_save_id = code_save.id
      reorder_save_id = reorder_save.id
      code_answer_id = code_answer.id
      reorder_answer_id = reorder_answer.id
      reorder_answerable_id = reorder_answer.answerable.id

      expect { user.destroy! }.not_to raise_error

      expect(Sangaku.exists?(code_sangaku_id)).to eq false
      expect(CodeSangaku.exists?(code_sangakuable_id)).to eq false
      expect(FixedInput.exists?(fixed_input_id)).to eq false
      expect(Sangaku.exists?(reorder_sangaku_id)).to eq false
      expect(ReorderSangaku.exists?(reorder_sangakuable_id)).to eq false
      expect(CodeBlock.where(id: reorder_code_block_ids).exists?).to eq false
      expect(UserSangakuSave.exists?(code_save_id)).to eq false
      expect(UserSangakuSave.exists?(reorder_save_id)).to eq false
      expect(Answer.exists?(code_answer_id)).to eq false
      expect(Answer.exists?(reorder_answer_id)).to eq false
      expect(AnswerResult.where(id: answer_result_ids).exists?).to eq false
      expect(ReorderAnswer.exists?(reorder_answerable_id)).to eq false
    end
  end

  describe ".search" do
    it "matches users whose email partially matches the query" do
      matching_user = create(:user, email: "taro@example.com")
      create(:user, email: "other@example.com")

      expect(User.search("taro")).to include(matching_user)
      expect(User.search("taro").count).to eq 1
    end

    it "matches users whose nickname partially matches the query" do
      matching_user = create(:user, nickname: "algo_taro")
      create(:user, nickname: "other")

      expect(User.search("taro")).to include(matching_user)
    end

    it "is case-insensitive" do
      matching_user = create(:user, nickname: "AlgoTaro")

      expect(User.search("algotaro")).to include(matching_user)
    end

    it "escapes the percent wildcard instead of matching every user" do
      literal_percent_user = create(:user, nickname: "50%off")
      other_user = create(:user, nickname: "regular")

      result = User.search("%")

      expect(result).to include(literal_percent_user)
      expect(result).not_to include(other_user)
    end

    it "escapes the underscore wildcard instead of matching any single character" do
      literal_underscore_user = create(:user, nickname: "a_b")
      other_user = create(:user, nickname: "aXb")

      result = User.search("a_b")

      expect(result).to include(literal_underscore_user)
      expect(result).not_to include(other_user)
    end

    it "escapes backslash characters in the query" do
      literal_backslash_user = create(:user, nickname: "a\\b")
      other_user = create(:user, nickname: "ab")

      result = User.search("a\\b")

      expect(result).to include(literal_backslash_user)
      expect(result).not_to include(other_user)
    end
  end
end
