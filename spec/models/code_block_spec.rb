require 'rails_helper'

RSpec.describe CodeBlock, type: :model do
  # 正解ブロックが常に必須になったため（issue #278）、create(:reorder_sangaku) は
  # そのままだと invalid になり保存できない。:with_code_blocks trait で
  # correct_position 1, 2 の code_block を持たせることで通常のバリデーションを
  # 通した状態で永続化する。この trait が 1, 2 を使用済みのため、このヘルパーを
  # 使う各テストで明示的な correct_position を指定する場合は 1, 2 との衝突に注意すること
  # （CodeBlock を直接 create しても親の構成バリデーションは再実行されないため、
  # 衝突するのは DB のユニーク制約のみ）。
  def build_persisted_reorder_sangaku
    create(:reorder_sangaku, :with_code_blocks)
  end

  describe 'validation' do
    it 'is valid with all attributes' do
      code_block = build(:code_block)
      expect(code_block).to be_valid
      expect(code_block.errors).to be_empty
    end

    it 'is invalid without content' do
      code_block = build(:code_block, content: "")
      expect(code_block).to be_invalid
      expect(code_block.errors[:content]).to eq [ 'を入力してください' ]
    end

    it 'is invalid with a content longer than 2000 characters' do
      code_block = build(:code_block, content: "a" * 2001)
      expect(code_block).to be_invalid
      expect(code_block.errors[:content]).to eq [ 'は2000文字以内で入力してください' ]
    end

    it 'is valid with a nil correct_position as a dummy block' do
      code_block = build(:code_block, correct_position: nil)
      expect(code_block).to be_valid
      expect(code_block.errors).to be_empty
    end
  end

  describe '#reorder_sangaku' do
    it 'belongs to a reorder_sangaku' do
      reorder_sangaku = build_persisted_reorder_sangaku
      # :with_code_blocks trait が correct_position 1, 2 を使用済みのため、
      # 位置の値に依存しないダミーブロックで検証する
      code_block = create(:code_block, :dummy, reorder_sangaku: reorder_sangaku)

      expect(code_block.reorder_sangaku).to eq reorder_sangaku
    end
  end

  describe 'uniqueness of correct_position' do
    it 'raises ActiveRecord::RecordNotUnique when correct_position is duplicated within the same reorder_sangaku' do
      reorder_sangaku = build_persisted_reorder_sangaku
      # :with_code_blocks trait が correct_position 1, 2 を使用済みのため、衝突しない値を使う
      create(:code_block, reorder_sangaku: reorder_sangaku, correct_position: 10)

      expect {
        create(:code_block, reorder_sangaku: reorder_sangaku, correct_position: 10)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows multiple code_blocks with a nil correct_position for the same reorder_sangaku' do
      reorder_sangaku = build_persisted_reorder_sangaku
      create(:code_block, reorder_sangaku: reorder_sangaku, correct_position: nil)

      expect {
        create(:code_block, reorder_sangaku: reorder_sangaku, correct_position: nil)
      }.not_to raise_error
    end

    it 'allows the same correct_position across different reorder_sangakus' do
      first_reorder_sangaku = build_persisted_reorder_sangaku
      second_reorder_sangaku = build_persisted_reorder_sangaku
      # :with_code_blocks trait が correct_position 1, 2 を使用済みのため、衝突しない値を使う
      create(:code_block, reorder_sangaku: first_reorder_sangaku, correct_position: 10)

      expect {
        create(:code_block, reorder_sangaku: second_reorder_sangaku, correct_position: 10)
      }.not_to raise_error
    end
  end
end
