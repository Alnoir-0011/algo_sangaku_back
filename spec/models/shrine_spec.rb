require 'rails_helper'

RSpec.describe Shrine, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      shrine = build(:shrine)
      expect(shrine).to be_valid
      expect(shrine.errors).to be_empty
    end

    it "is invalid without name" do
      shrine = build(:shrine, name: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:name]).to eq [ 'を入力してください' ]
    end

    it "is invalid without latitude" do
      shrine = build(:shrine, latitude: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:latitude]).to eq [ 'は数値で入力してください' ]
    end

    it "is invalid without longitude" do
      shrine = build(:shrine, longitude: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:longitude]).to eq [ 'は数値で入力してください' ]
    end


    it "is invalid with out address" do
      shrine = build(:shrine, address: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:address]).to eq [ 'を入力してください' ]
    end

    it "is invalid without place_id" do
      shrine = build(:shrine, place_id: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:place_id]).to eq [ 'を入力してください' ]
    end

    it "is invalid with non numeric latitude" do
      shrine = build(:shrine, latitude: "text_input")
      expect(shrine).to be_invalid
      expect(shrine.errors[:latitude]).to eq [ 'は数値で入力してください' ]
    end

    it "is invalid with non numeric longitude" do
      shrine = build(:shrine, longitude: "text_input")
      expect(shrine).to be_invalid
      expect(shrine.errors[:longitude]).to eq [ 'は数値で入力してください' ]
    end


    it "is invalid with same place_id" do
      shrine = create(:shrine)
      another_shirne = build(:shrine, place_id: shrine.place_id)
      expect(another_shirne).to be_invalid
      expect(another_shirne.errors[:place_id]).to eq [ 'はすでに存在します' ]
    end

    it "is valid with anotehr place_id" do
      create(:shrine)
      another_shirne = build(:shrine, place_id: "another_place_id")
      expect(another_shirne).to be_valid
      expect(another_shirne.errors).to be_empty
    end
  end
end
