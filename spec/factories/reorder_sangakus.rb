FactoryBot.define do
  factory :reorder_sangaku do
    description { "test_description" }
    difficulty { "easy" }

    # 正解ブロックが常に必須になったため（issue #278）、valid な最小構成
    # （正解ブロック2個）が欲しいテスト向けに opt-in の trait として用意する。
    # correct_position は固定値 1, 2 を使うため、この trait を使った
    # reorder_sangaku に対して明示的な correct_position を持つ code_block を
    # 追加する場合は値の重複に注意すること。
    trait :with_code_blocks do
      after(:build) do |reorder_sangaku|
        reorder_sangaku.code_blocks.build(content: "code_block_1", correct_position: 1)
        reorder_sangaku.code_blocks.build(content: "code_block_2", correct_position: 2)
      end
    end
  end
end
