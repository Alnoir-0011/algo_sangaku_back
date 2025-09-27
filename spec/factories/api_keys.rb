FactoryBot.define do
  factory :api_key do
    sequence(:access_token) { |n| "dummy_token_#{n}" }
    expires_at { "2025-06-17 15:34:29" }
    association :user
  end
end
