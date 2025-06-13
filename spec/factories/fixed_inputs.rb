FactoryBot.define do
  factory :fixed_input do
    sequence(:content) { |n| "test_input_#{n}" }
    association :sangaku
  end
end
