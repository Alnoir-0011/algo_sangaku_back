require 'rails_helper'

RSpec.describe CodeSangaku, type: :model do
  describe 'validation' do
    it 'is valid with all attributes' do
      code_sangaku = build(:code_sangaku)
      expect(code_sangaku).to be_valid
      expect(code_sangaku.errors).to be_empty
    end

    it 'is invalid without description' do
      code_sangaku = build(:code_sangaku, description: "")
      expect(code_sangaku).to be_invalid
      expect(code_sangaku.errors[:description]).to eq [ 'を入力してください' ]
    end

    it 'is invalid without source' do
      code_sangaku = build(:code_sangaku, source: "")
      expect(code_sangaku).to be_invalid
      expect(code_sangaku.errors[:source]).to eq [ 'を入力してください' ]
    end

    it 'is invalid with an unknown difficulty instead of raising an error' do
      code_sangaku = build(:code_sangaku, difficulty: "invalid_value")
      expect(code_sangaku).to be_invalid
      expect(code_sangaku.errors[:difficulty]).to be_present
    end

    it 'is invalid with duplicated fixed_inputs' do
      code_sangaku = build(:code_sangaku)
      code_sangaku.fixed_inputs.build(content: "duplicated")
      code_sangaku.fixed_inputs.build(content: "duplicated")

      expect(code_sangaku).to be_invalid
      expect(code_sangaku.errors[:fixed_inputs]).to eq [ 'が重複しています' ]
    end
  end

  describe '#save_with_inputs' do
    it 'removes a fixed_input that has answer_results without raising a foreign key violation' do
      sangaku = create(:sangaku)
      fixed_input = create(:fixed_input, sangaku: sangaku, content: "old_input")
      sangaku.reload
      user_sangaku_save = create(:user_sangaku_save, sangaku: sangaku)
      create(:answer, user_sangaku_save: user_sangaku_save)

      expect(sangaku.sangakuable.save_with_inputs([])).to eq true
      expect(FixedInput.exists?(fixed_input.id)).to eq false
    end

    it 'returns false when save! raises ActiveRecord::RecordInvalid' do
      code_sangaku = create(:sangaku).sangakuable
      allow(code_sangaku).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(code_sangaku))

      expect(code_sangaku.save_with_inputs([])).to eq false
    end

    it 'returns false when save! raises ActiveRecord::RecordNotUnique' do
      code_sangaku = create(:sangaku).sangakuable
      allow(code_sangaku).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique.new("duplicate key"))

      expect(code_sangaku.save_with_inputs([])).to eq false
    end

    it 'raises when an unexpected error occurs' do
      code_sangaku = create(:sangaku).sangakuable
      allow(code_sangaku).to receive(:save!).and_raise(StandardError, "unexpected error")

      expect { code_sangaku.save_with_inputs([]) }.to raise_error(StandardError, "unexpected error")
    end

    # コントローラは形式固有レコード側から親を組み立てるため、その経路で検証する
    it 'returns false when the parent sangaku is invalid' do
      code_sangaku = build(:code_sangaku)
      code_sangaku.build_sangaku(title: "", user: create(:user))

      expect(code_sangaku.save_with_inputs([])).to eq false
      expect(code_sangaku.sangaku.errors[:title]).to eq [ 'を入力してください' ]
    end

    it 'saves the parent sangaku together with the code_sangaku' do
      code_sangaku = build(:code_sangaku)
      code_sangaku.build_sangaku(title: "created_title", user: create(:user))

      expect(code_sangaku.save_with_inputs([ "input_a" ])).to eq true
      expect(code_sangaku.reload.sangaku.title).to eq "created_title"
      expect(code_sangaku.fixed_inputs.pluck(:content)).to eq [ "input_a" ]
    end
  end
end
