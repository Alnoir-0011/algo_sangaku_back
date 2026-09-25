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
  end

  # 形式固有のカラムは sangakuable が持つ（issue #278）
  # 形式を追加して KINDS を更新し忘れると、レスポンスの kind が null になり、kind フィルターも効かない
  describe 'KINDS' do
    it 'covers every sangakuable type registered in delegated_type' do
      expect(Sangaku::KINDS.values).to match_array(Sangaku.sangakuable_types)
    end
  end

  describe 'delegated_type' do
    it 'has a code_sangaku as its sangakuable' do
      sangaku = create(:sangaku)

      expect(sangaku.code_sangaku?).to eq true
      expect(sangaku.sangakuable).to be_a CodeSangaku
    end

    it 'delegates description and difficulty to the sangakuable' do
      sangaku = create(:sangaku, description: "delegated_description", difficulty: "normal")

      expect(sangaku.description).to eq "delegated_description"
      expect(sangaku.difficulty).to eq "normal"
    end

    it 'destroys the sangakuable when it is destroyed' do
      sangaku = create(:sangaku)
      code_sangaku = sangaku.sangakuable

      sangaku.destroy!

      expect(CodeSangaku.exists?(code_sangaku.id)).to eq false
    end

    context 'when the sangakuable is a reorder_sangaku' do
      it 'has a reorder_sangaku as its sangakuable' do
        sangaku = create(:sangaku, :reorder)

        expect(sangaku.reorder_sangaku?).to eq true
        expect(sangaku.code_sangaku?).to eq false
        expect(sangaku.sangakuable).to be_a ReorderSangaku
      end

      it 'delegates description and difficulty to the sangakuable' do
        sangaku = create(:sangaku, :reorder, description: "delegated_description", difficulty: "normal")

        expect(sangaku.description).to eq "delegated_description"
        expect(sangaku.difficulty).to eq "normal"
      end

      it 'destroys the sangakuable when it is destroyed' do
        sangaku = create(:sangaku, :reorder)
        reorder_sangaku = sangaku.sangakuable

        sangaku.destroy!

        expect(ReorderSangaku.exists?(reorder_sangaku.id)).to eq false
      end
    end
  end

  describe '.search' do
    it 'filters by difficulty even though the column lives on the sangakuable' do
      easy_sangaku = create(:sangaku, difficulty: "easy")
      normal_sangaku = create(:sangaku, difficulty: "normal")

      result = Sangaku.search({ difficulty: "normal" })

      expect(result).to include normal_sangaku
      expect(result).not_to include easy_sangaku
    end

    it 'ignores an unknown difficulty value' do
      easy_sangaku = create(:sangaku, difficulty: "easy")
      normal_sangaku = create(:sangaku, difficulty: "normal")

      result = Sangaku.search({ difficulty: "unknown" })

      expect(result).to include easy_sangaku, normal_sangaku
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

    it 'destroys associated code_blocks without raising a foreign key violation when the sangakuable is a reorder_sangaku' do
      sangaku = create(:sangaku, :reorder)
      # :reorder trait 側で correct_position 1, 2 の code_block が既に存在するため、
      # 衝突を避けるためダミーブロック（correct_position: nil）を追加する
      code_block = create(:code_block, :dummy, reorder_sangaku: sangaku.sangakuable)

      expect { sangaku.destroy! }.not_to raise_error
      expect(CodeBlock.exists?(code_block.id)).to eq false
    end

    it 'destroys the sangaku and its associated saves and answers without raising a foreign key violation when it is a reorder_sangaku saved and answered by another user' do
      sangaku = create(:sangaku, :reorder)
      reorder_sangaku_id = sangaku.sangakuable.id
      # 生成直後の code_blocks は :reorder trait 側のキャッシュが残る可能性があるため pluck で取り直す
      code_block_ids = sangaku.sangakuable.code_blocks.pluck(:id)
      other_user = create(:user)
      user_sangaku_save = create(:user_sangaku_save, user: other_user, sangaku: sangaku)
      answer = create(:answer, :reorder, user_sangaku_save: user_sangaku_save)

      sangaku_id = sangaku.id
      user_sangaku_save_id = user_sangaku_save.id
      answer_id = answer.id
      reorder_answer_id = answer.answerable.id

      expect { sangaku.destroy! }.not_to raise_error

      expect(Sangaku.exists?(sangaku_id)).to eq false
      expect(ReorderSangaku.exists?(reorder_sangaku_id)).to eq false
      expect(CodeBlock.where(id: code_block_ids).exists?).to eq false
      expect(UserSangakuSave.exists?(user_sangaku_save_id)).to eq false
      expect(Answer.exists?(answer_id)).to eq false
      expect(ReorderAnswer.exists?(reorder_answer_id)).to eq false
    end
  end

  describe '.representative_reorder_for' do
    def create_answered_reorder_sangaku(shrine:, answers_count:, created_at: Time.current)
      sangaku = create(:sangaku, :reorder, shrine: shrine, created_at: created_at)
      answers_count.times do
        user_sangaku_save = create(:user_sangaku_save, sangaku: sangaku)
        create(:answer, :reorder, user_sangaku_save: user_sangaku_save)
      end
      sangaku
    end

    it 'returns the reorder sangaku with the most answers for the shrine' do
      shrine = create(:shrine)
      fewer_answers_sangaku = create_answered_reorder_sangaku(shrine: shrine, answers_count: 1)
      most_answers_sangaku = create_answered_reorder_sangaku(shrine: shrine, answers_count: 3)

      result = Sangaku.representative_reorder_for(shrine)

      expect(result).to eq most_answers_sangaku
      expect(result).not_to eq fewer_answers_sangaku
    end

    context 'when the answer counts are tied' do
      # 同数のときに新しい算額を優先すると、後から量産した算額に代表の座を
      # 奪われる手口が成立してしまうため、古い方を優先する（issue #359 セキュリティレビュー対応）。
      it 'returns the sangaku with the older created_at' do
        shrine = create(:shrine)
        older_sangaku = create_answered_reorder_sangaku(shrine: shrine, answers_count: 2, created_at: 2.days.ago)
        newer_sangaku = create_answered_reorder_sangaku(shrine: shrine, answers_count: 2, created_at: 1.day.ago)

        result = Sangaku.representative_reorder_for(shrine)

        expect(result).to eq older_sangaku
        expect(result).not_to eq newer_sangaku
      end
    end

    context 'when the shrine has no reorder sangaku' do
      it 'returns nil even if the shrine has a code sangaku' do
        shrine = create(:shrine)
        create(:sangaku, shrine: shrine)

        result = Sangaku.representative_reorder_for(shrine)

        expect(result).to be_nil
      end
    end

    context 'when a code sangaku has more answers than the reorder sangaku' do
      it 'excludes the code sangaku from the candidates' do
        shrine = create(:shrine)
        code_sangaku = create(:sangaku, shrine: shrine)
        3.times do
          user_sangaku_save = create(:user_sangaku_save, sangaku: code_sangaku)
          create(:answer, user_sangaku_save: user_sangaku_save)
        end
        reorder_sangaku = create_answered_reorder_sangaku(shrine: shrine, answers_count: 1)

        result = Sangaku.representative_reorder_for(shrine)

        expect(result).to eq reorder_sangaku
      end
    end

    context 'when shrine is nil' do
      it 'returns nil' do
        result = Sangaku.representative_reorder_for(nil)

        expect(result).to be_nil
      end
    end

    context 'when the shrine has exactly one reorder sangaku with no answers' do
      it 'returns that sangaku' do
        shrine = create(:shrine)
        only_sangaku = create_answered_reorder_sangaku(shrine: shrine, answers_count: 0)

        result = Sangaku.representative_reorder_for(shrine)

        expect(result).to eq only_sangaku
      end
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
