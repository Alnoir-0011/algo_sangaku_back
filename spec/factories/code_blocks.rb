FactoryBot.define do
  factory :code_block do
    association :reorder_sangaku
    content { "test_content" }
    sequence(:correct_position) { |n| n }

    # 正解位置を持たないダミーブロック
    trait :dummy do
      correct_position { nil }
    end
  end
end
