require 'rails_helper'

RSpec.describe Sangaku, type: :model do
  describe 'validation' do
    it 'is valid with all attribute' do
      sangaku = build(:sangaku)
      expect(sangaku).to be_valid
      expect(sangaku.errors).to be_empty
    end

    it 'is invalid without title' do
      sangaku = build(:sangaku, title: "")
      expect(sangaku).to be_invalid
      expect(sangaku.errors[:title]).to eq ['を入力してください']
    end

    it 'is invalid without description' do
      sangaku = build(:sangaku, description: "")
      expect(sangaku).to be_invalid
      expect(sangaku.errors[:description]).to eq ['を入力してください']
    end

    it 'is invalid without source' do
      sangaku = build(:sangaku, source: "")
      expect(sangaku).to be_invalid
      expect(sangaku.errors[:title]).to eq ['を入力してください']
    end
  end
end
