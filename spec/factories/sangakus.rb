FactoryBot.define do
  factory :sangaku do
    title { "test_title" }
    description { "test_description" }
    source { "puts 'Hello world'" }
    difficulty { "easy" }
    association :user
    # shrine_id { nil }

    trait :with_fixed_inputs do
      after(:build) do
        build_list(:fixed_inputs, 3)
      end
    end
  end
end
