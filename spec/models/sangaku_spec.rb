require 'rails_helper'

RSpec.describe Sangaku, type: :model do
  describe 'validation' do
    it 'is valid with all attributes' do
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

  describe '#destroy' do
    it 'destroys the sangaku without raising a foreign key violation when a fixed_input has answer_results' do
      sangaku = create(:sangaku)
      fixed_input = create(:fixed_input, sangaku: sangaku)
      sangaku.reload
      user_sangaku_save = create(:user_sangaku_save, sangaku: sangaku)
      create(:answer, user_sangaku_save: user_sangaku_save)

      expect { sangaku.destroy! }.not_to raise_error
      expect(FixedInput.exists?(fixed_input.id)).to eq false
    end
  end

  describe '#save_with_inputs' do
    it 'removes a fixed_input that has answer_results without raising a foreign key violation' do
      sangaku = create(:sangaku)
      fixed_input = create(:fixed_input, sangaku: sangaku, content: "old_input")
      sangaku.reload
      user_sangaku_save = create(:user_sangaku_save, sangaku: sangaku)
      create(:answer, user_sangaku_save: user_sangaku_save)

      expect(sangaku.save_with_inputs([])).to eq true
      expect(FixedInput.exists?(fixed_input.id)).to eq false
    end

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

  # lat/lng はクライアント（HTTPリクエストパラメータ）からそのまま渡される申告値であり、
  # このテストはあくまで距離計算に基づく閾値判定ロジックの正しさを検証するもの。
  # サーバー側で位置情報の真正性を検証していないため、この距離チェックはUX上の制約であり
  # 位置偽装（なりすまし奉納）に対するセキュリティ境界にはならない（issue #312 で対応方針を検討）。
  describe '#dedicate' do
    it 'dedicates the sangaku when the distance is within the default threshold' do
      sangaku = create(:sangaku, shrine: nil)
      shrine = create(:shrine, latitude: 35.4, longitude: 135.1)

      expect(sangaku.dedicate(shrine, 35.4, 135.1)).to eq true
      expect(sangaku.reload.shrine).to eq shrine
    end

    it 'does not dedicate the sangaku when the distance exceeds the default threshold' do
      sangaku = create(:sangaku, shrine: nil)
      shrine = create(:shrine, latitude: 35.4, longitude: 135.1)

      expect(sangaku.dedicate(shrine, 35.41, 135.1)).to eq false
      expect(sangaku.reload.shrine).to be_nil
    end

    it 'does not dedicate the sangaku when it already has a shrine, regardless of distance' do
      existing_shrine = create(:shrine, latitude: 35.4, longitude: 135.1)
      sangaku = create(:sangaku, shrine: existing_shrine)
      # 意図的に existing_shrine と異なる座標にし、「距離判定ではなく既存shrineの有無で
      # 短絡的に弾かれている」ことを明確にする
      new_shrine = create(:shrine, latitude: 43.0, longitude: 141.3)

      expect(sangaku.dedicate(new_shrine, 43.0, 141.3)).to eq false
      expect(sangaku.reload.shrine).to eq existing_shrine
    end

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
