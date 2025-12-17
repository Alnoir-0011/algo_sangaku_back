FactoryBot.define do
  factory :answer_result do
    association :answer
    association :fixed_input
    output { "Hello world\n" }
    status { "pending" }
  end
end
