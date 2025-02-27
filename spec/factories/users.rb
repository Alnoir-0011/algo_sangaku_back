FactoryBot.define do
  factory :user do
    provider { "google" }
    uid { SecureRandom.uuid }
    name { "test user" }
    sequence(:email) { |n| "user_#{n}@example.com"}
    nickname { "test nickname" }
  end
end
