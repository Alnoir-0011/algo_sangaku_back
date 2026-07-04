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
      expect(sangaku.errors[:title]).to eq [ 'を入力してください' ]
    end

    it 'is invalid without description' do
      sangaku = build(:sangaku, description: "")
      expect(sangaku).to be_invalid
      expect(sangaku.errors[:description]).to eq [ 'を入力してください' ]
    end

    it 'is invalid without source' do
      sangaku = build(:sangaku, source: "")
      expect(sangaku).to be_invalid
      expect(sangaku.errors[:source]).to eq [ 'を入力してください' ]
    end
  end

  describe '#save_with_inputs' do
    it 'returns false when save! raises ActiveRecord::RecordInvalid' do
      sangaku = create(:sangaku)
      allow(sangaku).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(sangaku))

      expect(sangaku.save_with_inputs([])).to eq false
    end

    it 'returns false when save! raises ActiveRecord::RecordNotUnique' do
      sangaku = create(:sangaku)
      allow(sangaku).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique.new("duplicate key"))

      expect(sangaku.save_with_inputs([])).to eq false
    end

    it 'raises when an unexpected error occurs' do
      sangaku = create(:sangaku)
      allow(sangaku).to receive(:save!).and_raise(StandardError, "unexpected error")

      expect { sangaku.save_with_inputs([]) }.to raise_error(StandardError, "unexpected error")
    end
  end

  describe '#dedicate' do
    it 'returns false when save! raises ActiveRecord::RecordInvalid' do
      sangaku = create(:sangaku)
      shrine = create(:shrine)
      allow(sangaku).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(sangaku))

      expect(sangaku.dedicate(shrine, shrine.latitude, shrine.longitude)).to eq false
    end

    it 'raises when an unexpected error occurs' do
      sangaku = create(:sangaku)
      shrine = create(:shrine)
      allow(sangaku).to receive(:save!).and_raise(StandardError, "unexpected error")

      expect { sangaku.dedicate(shrine, shrine.latitude, shrine.longitude) }.to raise_error(StandardError, "unexpected error")
    end
  end
end
