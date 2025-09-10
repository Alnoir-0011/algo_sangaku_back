FactoryBot.define do
  factory :answer do
    association :user_sangaku_save
    source { "puts 'Hello world'" }
  end
end
