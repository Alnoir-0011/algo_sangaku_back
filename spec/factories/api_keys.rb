FactoryBot.define do
  factory :api_key do
    sequence(:access_token) { |n| "dummy_token_#{n}" }
    expires_at { 1.week.from_now }
    association :user

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
