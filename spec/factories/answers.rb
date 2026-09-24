FactoryBot.define do
  # 親（delegated_type）の factory。
  # source は形式固有のため transient で受け取り、既定では CodeAnswer を answerable にする。
  factory :answer do
    association :user_sangaku_save

    transient do
      source { "puts 'Hello world'" }
      result { :correct }
    end

    answerable { association(:code_answer, source:) }

    # 並べ替え形式（ReorderAnswer）を answerable にする（issue #278）
    trait :reorder do
      answerable { association(:reorder_answer, result:) }
    end
  end
end
