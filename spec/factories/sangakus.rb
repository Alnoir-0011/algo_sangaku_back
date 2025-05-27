FactoryBot.define do
  factory :sangaku do
    title { "test_title" }
    description { "test_description" }
    source { "put 'Hello world'" }
    difficulty { "easy" }
    association :user
    association :shrine
  end
end
