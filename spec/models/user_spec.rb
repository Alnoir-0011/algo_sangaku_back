require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validation" do
    it "is valid with all attribute" do
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
      user = build(:user, name: '')
      expect(user).to be_invalid
      expect(user.errors[:name]).to eq [ 'を入力してください' ]
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

    it "is valid with same email" do
      user = create(:user)
      another_user = build(:user, email: user.email)
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
      another_user = build(:user, email: user.nickname)
      expect(another_user).to be_valid
      expect(another_user.errors).to be_empty
    end
  end
end
