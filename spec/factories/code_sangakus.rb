FactoryBot.define do
  factory :code_sangaku do
    description { "test_description" }
    source { "puts 'Hello world'" }
    difficulty { "easy" }

    # 親を伴う形式固有レコードが必要なとき（作成・更新の検証など）に使う
    trait :with_sangaku do
      after(:build) do |code_sangaku|
        code_sangaku.sangaku ||= build(:sangaku, sangakuable: code_sangaku)
      end
    end
  end
end
