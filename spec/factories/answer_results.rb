FactoryBot.define do
  factory :answer_result do
    # 既存 spec の create(:answer_result, answer:) をそのまま使えるようにする。
    # answer を省略した場合は親 Answer ごと作り、その answerable にぶら下げる。
    transient do
      answer { association(:answer) }
    end

    code_answer { answer.answerable }
    association :fixed_input
    output { "Hello world\n" }
    status { "pending" }
  end
end
