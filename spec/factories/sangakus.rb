FactoryBot.define do
  # 親（delegated_type）の factory。
  # 形式固有の属性は transient で受け取り、既定では CodeSangaku を sangakuable にする。
  # これにより既存 spec の create(:sangaku, difficulty: "normal") のような呼び出しをそのまま使える。
  factory :sangaku do
    title { "test_title" }
    association :user

    transient do
      description { "test_description" }
      source { "puts 'Hello world'" }
      difficulty { "easy" }
    end

    sangakuable { association(:code_sangaku, description:, source:, difficulty:) }

    # 並べ替え形式（ReorderSangaku）を sangakuable にする（issue #278）
    # 正解ブロックが常に必須になったため、:with_code_blocks trait を付けて
    # 常に valid な reorder_sangaku を組み立てる
    trait :reorder do
      sangakuable { association(:reorder_sangaku, :with_code_blocks, description:, difficulty:) }
    end

    trait :with_fixed_inputs do
      transient do
        fixed_input_contents { %w[input_1 input_2 input_3] }
      end

      after(:create) do |sangaku, evaluator|
        evaluator.fixed_input_contents.each do |content|
          create(:fixed_input, code_sangaku: sangaku.sangakuable, content:)
        end
        sangaku.reload
      end
    end
  end
end
