FactoryBot.define do
  factory :api_key do
    transient do
      raw_token { SecureRandom.uuid }
    end

    access_token { ApiKey.digest(raw_token) }
    expires_at { 1.week.from_now }
    association :user

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
