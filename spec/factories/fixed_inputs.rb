FactoryBot.define do
  factory :fixed_input do
    content { "test_input" }
    association :sangaku
  end
end
