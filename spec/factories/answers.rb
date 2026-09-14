FactoryBot.define do
  # 親（delegated_type）の factory。
  # source は形式固有のため transient で受け取り、既定では CodeAnswer を answerable にする。
  factory :answer do
    association :user_sangaku_save

    transient do
      source { "puts 'Hello world'" }
    end

    answerable { association(:code_answer, source:) }
  end
end
