require 'rails_helper'

RSpec.describe ReorderSangaku, type: :model do
  describe 'validation' do
    it 'is valid with all attributes' do
      # 正解ブロックが常に必須になったため（issue #278）、有効な最小構成を持つ trait を使う
      reorder_sangaku = build(:reorder_sangaku, :with_code_blocks)
      expect(reorder_sangaku).to be_valid
      expect(reorder_sangaku.errors).to be_empty
    end

    it 'is invalid without description' do
      reorder_sangaku = build(:reorder_sangaku, description: "")
      expect(reorder_sangaku).to be_invalid
      expect(reorder_sangaku.errors[:description]).to eq [ 'を入力してください' ]
    end

    it 'is invalid with a description longer than 65535 characters' do
      reorder_sangaku = build(:reorder_sangaku, description: "a" * 65_536)
      expect(reorder_sangaku).to be_invalid
      expect(reorder_sangaku.errors[:description]).to eq [ 'は65535文字以内で入力してください' ]
    end

    it 'is invalid without difficulty' do
      reorder_sangaku = build(:reorder_sangaku, difficulty: nil)
      expect(reorder_sangaku).to be_invalid
      expect(reorder_sangaku.errors[:difficulty]).to eq [ 'を入力してください' ]
    end

    it 'is invalid with an unknown difficulty instead of raising an error' do
      reorder_sangaku = build(:reorder_sangaku, :with_code_blocks, difficulty: "invalid_value")
      expect(reorder_sangaku).to be_invalid
      expect(reorder_sangaku.errors[:difficulty]).to be_present
    end

    it 'responds to the prefixed difficulty predicate method' do
      reorder_sangaku = build(:reorder_sangaku, difficulty: "normal")
      expect(reorder_sangaku.difficulty_normal?).to eq true
    end
  end

  describe '#code_blocks' do
    it 'destroys associated code_blocks when destroyed' do
      # 正解ブロックが常に必須になったため（issue #278）、有効な最小構成を持つ trait で作成する
      reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
      # trait 側で correct_position 1, 2 の code_block が既に存在するため、
      # 衝突を避けるためダミーブロック（correct_position: nil）を追加する
      code_block = create(:code_block, :dummy, reorder_sangaku: reorder_sangaku)

      expect { reorder_sangaku.destroy! }.not_to raise_error
      expect(CodeBlock.exists?(code_block.id)).to eq false
    end
  end

  describe 'code_blocks composition validation' do
    # correct_position を明示指定するための Arrange ヘルパー。
    # factory の sequence(:correct_position) はスイート全体で通し番号になり
    # [1, 2, 3] のような具体値の検証には使えないため、ここで明示的に構築する。
    def add_correct_code_blocks(reorder_sangaku, positions)
      positions.each do |position|
        reorder_sangaku.code_blocks.build(content: "content-#{position}", correct_position: position)
      end
    end

    def add_dummy_code_blocks(reorder_sangaku, count)
      count.times do |i|
        reorder_sangaku.code_blocks.build(content: "dummy-#{i}", correct_position: nil)
      end
    end

    context 'when there are two or more correct code_blocks with sequential positions starting from one' do
      it 'is valid' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 1, 2, 3 ])

        expect(reorder_sangaku).to be_valid
      end
    end

    context 'without any code_blocks' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'without any correct code_blocks' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_dummy_code_blocks(reorder_sangaku, 2)

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'with only one correct code_block' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 1 ])

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'when correct_positions do not start from one' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 2, 3 ])

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'when correct_positions have a gap' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 1, 3 ])

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'when correct_positions start from zero' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 0, 1 ])

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'when correct_positions include a negative number' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ -1, 2 ])

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end

    context 'with dummy code_blocks mixed among correct code_blocks' do
      it 'is valid regardless of how many dummy blocks are mixed in' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 1, 2 ])
        add_dummy_code_blocks(reorder_sangaku, 3)

        expect(reorder_sangaku).to be_valid
      end
    end

    context 'when the total number of code_blocks equals MAX_CODE_BLOCKS' do
      it 'is valid' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 1, 2 ])
        add_dummy_code_blocks(reorder_sangaku, ReorderSangaku::MAX_CODE_BLOCKS - 2)

        expect(reorder_sangaku).to be_valid
      end
    end

    context 'when the total number of code_blocks exceeds MAX_CODE_BLOCKS' do
      it 'is invalid and adds an error to the code_blocks attribute' do
        reorder_sangaku = build(:reorder_sangaku)
        add_correct_code_blocks(reorder_sangaku, [ 1, 2 ])
        add_dummy_code_blocks(reorder_sangaku, ReorderSangaku::MAX_CODE_BLOCKS - 1)

        expect(reorder_sangaku).to be_invalid
        expect(reorder_sangaku.errors[:code_blocks]).to be_present
      end
    end
  end

  describe '.valid_block_ids?' do
    it 'returns true for a non-empty array of unique integers within MAX_CODE_BLOCKS' do
      expect(ReorderSangaku.valid_block_ids?([ 3, 1, 2 ])).to eq true
      expect(ReorderSangaku.valid_block_ids?((1..ReorderSangaku::MAX_CODE_BLOCKS).to_a)).to eq true
    end

    {
      'nil' => nil,
      'a string' => "1,2",
      'an empty array' => [],
      'a numeric string element' => [ 1, "2" ],
      'a float element' => [ 1, 2.0 ],
      'duplicated ids' => [ 1, 1 ],
      'more ids than MAX_CODE_BLOCKS' => (1..(ReorderSangaku::MAX_CODE_BLOCKS + 1)).to_a,
      'a zero element' => [ 0, 1 ],
      'a negative element' => [ -1, 1 ],
      'an element beyond the postgres bigint range' => [ ReorderSangaku::POSTGRES_BIGINT_MAX + 1, 1 ]
    }.each do |label, block_ids|
      it "returns false for #{label}" do
        expect(ReorderSangaku.valid_block_ids?(block_ids)).to eq false
      end
    end

    it 'returns true for the boundary value of the postgres bigint range' do
      expect(ReorderSangaku.valid_block_ids?([ ReorderSangaku::POSTGRES_BIGINT_MAX ])).to eq true
    end
  end

  describe '#judge' do
    context 'with valid and correct block_ids' do
      it 'returns :correct' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

        expect(reorder_sangaku.judge(correct_block_ids)).to eq :correct
      end
    end

    context 'with valid but incorrect block_ids' do
      it 'returns :incorrect' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

        expect(reorder_sangaku.judge(correct_block_ids.reverse)).to eq :incorrect
      end
    end

    context 'with malformed block_ids' do
      it 'returns nil without raising' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)

        expect(reorder_sangaku.judge("invalid")).to be_nil
      end
    end
  end

  describe 'MAX_CODE_BLOCKS' do
    it 'is defined as 100' do
      expect(ReorderSangaku::MAX_CODE_BLOCKS).to eq 100
    end
  end

  describe '#save_with_code_blocks' do
    it 'replaces all existing code_blocks with the given ones' do
      sangaku = create(:sangaku, :reorder)
      reorder_sangaku = sangaku.sangakuable
      old_block_ids = reorder_sangaku.code_blocks.ids
      new_blocks = [
        { content: "new_content_1", correct_position: 1 },
        { content: "new_content_2", correct_position: 2 }
      ]

      expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq true
      expect(CodeBlock.where(id: old_block_ids)).to be_empty
      expect(reorder_sangaku.reload.code_blocks.pluck(:content, :correct_position)).to match_array(
        [ [ "new_content_1", 1 ], [ "new_content_2", 2 ] ]
      )
    end

    it 'persists the code_blocks in the order produced by the injected shuffler instead of the given order' do
      sangaku = create(:sangaku, :reorder)
      reorder_sangaku = sangaku.sangakuable
      new_blocks = [
        { content: "content_1", correct_position: 1 },
        { content: "content_2", correct_position: 2 },
        { content: "content_3", correct_position: 3 }
      ]
      reverse_shuffler = ->(items) { items.reverse }

      expect(reorder_sangaku.save_with_code_blocks(new_blocks, shuffler: reverse_shuffler)).to eq true
      persisted_order = reorder_sangaku.reload.code_blocks.order(:id).pluck(:correct_position)
      expect(persisted_order).to eq [ 3, 2, 1 ]
    end

    # どのブロックが問題かフロントで示せるよう、エラーに送信順の位置を入れる。
    # INSERT 前にシャッフルするため、保存後の並びではなく送信順で番号を振る（issue #278）
    context 'when a block has an invalid content' do
      it 'reports the position of a blank content in the submitted order' do
        sangaku = create(:sangaku, :reorder)
        reorder_sangaku = sangaku.sangakuable
        new_blocks = [
          { content: "content_1", correct_position: 1 },
          { content: "", correct_position: 2 },
          { content: "content_3", correct_position: 3 }
        ]

        expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq false
        expect(reorder_sangaku.errors[:code_blocks]).to include "の2番目の内容を入力してください"
      end

      it 'reports the position of a too long content in the submitted order' do
        sangaku = create(:sangaku, :reorder)
        reorder_sangaku = sangaku.sangakuable
        new_blocks = [
          { content: "content_1", correct_position: 1 },
          { content: "content_2", correct_position: 2 },
          { content: "a" * 2001, correct_position: 3 }
        ]

        expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq false
        expect(reorder_sangaku.errors[:code_blocks]).to include "の3番目は2000文字以内にしてください"
      end

      # 番号が保存後の並び（シャッフル済み）ではなく送信順であることを、並びを固定して確かめる
      it 'numbers the blocks by the submitted order even when the persisted order differs' do
        sangaku = create(:sangaku, :reorder)
        reorder_sangaku = sangaku.sangakuable
        new_blocks = [
          { content: "", correct_position: 1 },
          { content: "content_2", correct_position: 2 }
        ]
        reverse_shuffler = ->(items) { items.reverse }

        expect(reorder_sangaku.save_with_code_blocks(new_blocks, shuffler: reverse_shuffler)).to eq false
        expect(reorder_sangaku.errors[:code_blocks]).to include "の1番目の内容を入力してください"
      end

      # 正解が画面やログに出ないよう、メッセージにブロックの内容そのものを含めない
      it 'does not include the content itself in the message' do
        sangaku = create(:sangaku, :reorder)
        reorder_sangaku = sangaku.sangakuable
        new_blocks = [
          { content: "secret_answer_block", correct_position: 1 },
          { content: "a" * 2001, correct_position: 2 }
        ]

        expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq false
        expect(reorder_sangaku.errors[:code_blocks].join).not_to include "secret_answer_block"
      end
    end

    context 'when the new composition is invalid' do
      it 'returns false and keeps the existing code_blocks unchanged' do
        sangaku = create(:sangaku, :reorder)
        reorder_sangaku = sangaku.sangakuable
        original_contents = reorder_sangaku.code_blocks.pluck(:content, :correct_position)
        invalid_blocks = [ { content: "only_one", correct_position: 1 } ]

        expect(reorder_sangaku.save_with_code_blocks(invalid_blocks)).to eq false
        expect(reorder_sangaku.reload.code_blocks.pluck(:content, :correct_position)).to match_array(original_contents)
      end
    end

    it 'keeps the existing code_blocks when save! raises an error' do
      sangaku = create(:sangaku, :reorder)
      reorder_sangaku = sangaku.sangakuable
      old_block_ids = reorder_sangaku.code_blocks.ids
      allow(reorder_sangaku).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(reorder_sangaku))
      new_blocks = [
        { content: "new_content_1", correct_position: 1 },
        { content: "new_content_2", correct_position: 2 }
      ]

      expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq false
      expect(CodeBlock.where(id: old_block_ids).count).to eq old_block_ids.size
    end

    it 'returns false when save! raises ActiveRecord::RecordInvalid' do
      reorder_sangaku = create(:sangaku, :reorder).sangakuable
      allow(reorder_sangaku).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(reorder_sangaku))

      expect(reorder_sangaku.save_with_code_blocks([])).to eq false
    end

    it 'returns false when save! raises ActiveRecord::RecordNotUnique' do
      reorder_sangaku = create(:sangaku, :reorder).sangakuable
      allow(reorder_sangaku).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique.new("duplicate key"))

      expect(reorder_sangaku.save_with_code_blocks([])).to eq false
    end

    it 'raises when an unexpected error occurs' do
      reorder_sangaku = create(:sangaku, :reorder).sangakuable
      allow(reorder_sangaku).to receive(:save!).and_raise(StandardError, "unexpected error")

      expect { reorder_sangaku.save_with_code_blocks([]) }.to raise_error(StandardError, "unexpected error")
    end

    # コントローラは形式固有レコード側から親を組み立てるため、その経路で検証する
    it 'returns false when the parent sangaku is invalid' do
      reorder_sangaku = build(:reorder_sangaku)
      reorder_sangaku.build_sangaku(title: "", user: create(:user))
      new_blocks = [
        { content: "content_1", correct_position: 1 },
        { content: "content_2", correct_position: 2 }
      ]

      expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq false
      expect(reorder_sangaku.sangaku.errors[:title]).to eq [ 'を入力してください' ]
    end

    it 'saves the parent sangaku together with the reorder_sangaku' do
      reorder_sangaku = build(:reorder_sangaku)
      reorder_sangaku.build_sangaku(title: "created_title", user: create(:user))
      new_blocks = [
        { content: "content_1", correct_position: 1 },
        { content: "content_2", correct_position: 2 }
      ]

      expect(reorder_sangaku.save_with_code_blocks(new_blocks)).to eq true
      expect(reorder_sangaku.reload.sangaku.title).to eq "created_title"
      expect(reorder_sangaku.code_blocks.pluck(:content, :correct_position)).to match_array(
        [ [ "content_1", 1 ], [ "content_2", 2 ] ]
      )
    end
  end

  describe '#correct?' do
    # content 列で比較する挙動を検証するための Arrange ヘルパー。
    # trait :with_code_blocks の 2 件を消してから、任意の content 列で組み直す。
    def create_reorder_sangaku_with_contents(contents)
      reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
      reorder_sangaku.code_blocks.destroy_all
      contents.each_with_index do |content, index|
        create(:code_block, reorder_sangaku: reorder_sangaku, content: content, correct_position: index + 1)
      end
      reorder_sangaku.code_blocks.reload
      reorder_sangaku
    end

    context 'when the given block_ids are in the correct content order' do
      it 'returns true' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

        expect(reorder_sangaku.correct?(correct_block_ids)).to eq true
      end
    end

    context 'when the given block_ids include the correct blocks but in the wrong order' do
      it 'returns false' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)
        wrong_order_block_ids = correct_block_ids.reverse

        expect(reorder_sangaku.correct?(wrong_order_block_ids)).to eq false
      end
    end

    context 'when multiple code_blocks share the same content' do
      it 'returns true for a different id sequence that still produces the correct content order' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b a])
        first_a, b, second_a = reorder_sangaku.code_blocks.order(:correct_position).to_a
        # 1 番目と 3 番目の "a" ブロックの id を入れ替えても content の並びは ["a", "b", "a"] のまま
        swapped_block_ids = [ second_a.id, b.id, first_a.id ]

        expect(reorder_sangaku.correct?(swapped_block_ids)).to eq true
      end
    end

    it 'does not create any ReorderAnswer records' do
      reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
      correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

      expect {
        reorder_sangaku.correct?(correct_block_ids)
      }.not_to change(ReorderAnswer, :count)
    end

    # 判定はログインユーザーに依存しない（ゲストへの開放でもそのまま使うため）
    it 'judges without loading any user' do
      reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
      correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

      queries = capture_executed_sql { reorder_sangaku.correct?(correct_block_ids) }

      expect(queries).not_to include(a_string_matching(/FROM "users"/i))
    end

    it 'does not carry over the result of a previous judgement' do
      reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
      correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

      expect(reorder_sangaku.correct?(correct_block_ids.reverse)).to eq false
      expect(reorder_sangaku.correct?(correct_block_ids)).to eq true
      expect(reorder_sangaku.correct?(correct_block_ids.reverse)).to eq false
    end

    # 以下はいずれも「エラーではなく不正解（false）」であることを固定する回帰テスト。
    # 解答としては保存される（永続化は呼び出し側の責務）。
    context 'when a dummy block is included in the answer' do
      it 'returns false' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        dummy = create(:code_block, :dummy, reorder_sangaku: reorder_sangaku, content: "dummy_content")
        correct_blocks = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).to_a

        block_ids = [ correct_blocks.first.id, dummy.id, correct_blocks.last.id ]

        expect(reorder_sangaku.correct?(block_ids)).to eq false
      end
    end

    context 'when some of the correct blocks are missing' do
      it 'returns false' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        correct_block_ids = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)

        expect(reorder_sangaku.correct?(correct_block_ids.first(1))).to eq false
      end
    end

    context 'when an extra block is appended to the correct order' do
      it 'returns false' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        extra = create(:code_block, :dummy, reorder_sangaku: reorder_sangaku, content: "extra_content")
        correct_block_ids = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)

        expect(reorder_sangaku.correct?(correct_block_ids + [ extra.id ])).to eq false
      end
    end

    context "when block ids of another reorder_sangaku are included" do
      it 'returns false even though the other problem has the same contents in the same order' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        another_reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        correct_block_ids = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)
        another_block_ids = another_reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)

        # 自分のブロックだけを対象にするため、content が完全に一致していても採用されない
        expect(reorder_sangaku.correct?(another_block_ids)).to eq false
        expect(reorder_sangaku.correct?([ correct_block_ids.first, another_block_ids.last ])).to eq false
      end
    end

    context 'when a nonexistent block id is included' do
      it 'returns false' do
        reorder_sangaku = create(:reorder_sangaku, :with_code_blocks)
        correct_block_ids = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)
        nonexistent_id = CodeBlock.maximum(:id) + 1_000_000

        expect(reorder_sangaku.correct?([ correct_block_ids.first, nonexistent_id ])).to eq false
      end
    end

    # サイドチャネル対策: block_ids の件数によって実行経路が分岐しない（早期リターンをしない）ことを
    # 発行される SQL で検証する回帰テスト。
    # 現時点の実装は早期リターンを持たないためパスする想定で、将来「件数が違えば即 false」という
    # 最適化が入ると、片方のクエリが発行されなくなり失敗する。
    # マッチングクエリの WHERE 句は件数によって "id" IN (...) と "id" = ... に変わるため、
    # 判別は SELECT 句（id と content を引いていること）で行う。
    def code_blocks_select_queries(queries)
      queries.select { |sql| sql.match?(/SELECT.*FROM "code_blocks"/i) }
    end

    context 'when the number of given block_ids matches the number of correct blocks' do
      it 'executes both the correct-order content query and the id-to-content matching query' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

        queries = code_blocks_select_queries(capture_executed_sql { reorder_sangaku.correct?(correct_block_ids) })

        expect(queries).to include(a_string_matching(/SELECT\s+"code_blocks"\."content"\s+FROM "code_blocks".*"correct_position" IS NOT NULL/i))
        expect(queries).to include(a_string_matching(/SELECT\s+"code_blocks"\."id",\s*"code_blocks"\."content"\s+FROM "code_blocks"/i))
      end
    end

    context 'when the number of given block_ids is fewer than the number of correct blocks' do
      it 'executes both the correct-order content query and the id-to-content matching query' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        correct_block_ids = reorder_sangaku.code_blocks.order(:correct_position).pluck(:id)

        queries = code_blocks_select_queries(capture_executed_sql { reorder_sangaku.correct?(correct_block_ids.first(1)) })

        expect(queries).to include(a_string_matching(/SELECT\s+"code_blocks"\."content"\s+FROM "code_blocks".*"correct_position" IS NOT NULL/i))
        expect(queries).to include(a_string_matching(/SELECT\s+"code_blocks"\."id",\s*"code_blocks"\."content"\s+FROM "code_blocks"/i))
      end
    end

    context 'when the number of given block_ids is greater than the number of correct blocks' do
      it 'executes both the correct-order content query and the id-to-content matching query' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        extra = create(:code_block, :dummy, reorder_sangaku: reorder_sangaku, content: "extra_content")
        correct_block_ids = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)

        queries = code_blocks_select_queries(capture_executed_sql { reorder_sangaku.correct?(correct_block_ids + [ extra.id ]) })

        expect(queries).to include(a_string_matching(/SELECT\s+"code_blocks"\."content"\s+FROM "code_blocks".*"correct_position" IS NOT NULL/i))
        expect(queries).to include(a_string_matching(/SELECT\s+"code_blocks"\."id",\s*"code_blocks"\."content"\s+FROM "code_blocks"/i))
      end
    end

    context 'when comparing the number of executed queries across matching, insufficient, and excess block_ids counts' do
      it 'issues the same number of code_blocks queries regardless of whether the count matches, falls short, or exceeds' do
        reorder_sangaku = create_reorder_sangaku_with_contents(%w[a b])
        extra = create(:code_block, :dummy, reorder_sangaku: reorder_sangaku, content: "extra_content")
        correct_block_ids = reorder_sangaku.code_blocks.where.not(correct_position: nil).order(:correct_position).pluck(:id)

        matching_queries = code_blocks_select_queries(capture_executed_sql { reorder_sangaku.correct?(correct_block_ids) })
        insufficient_queries = code_blocks_select_queries(capture_executed_sql { reorder_sangaku.correct?(correct_block_ids.first(1)) })
        excess_queries = code_blocks_select_queries(capture_executed_sql { reorder_sangaku.correct?(correct_block_ids + [ extra.id ]) })

        expect(matching_queries.size).to eq 2
        expect(insufficient_queries.size).to eq matching_queries.size
        expect(excess_queries.size).to eq matching_queries.size
      end
    end
  end
end
