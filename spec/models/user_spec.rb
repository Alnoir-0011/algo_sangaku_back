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
