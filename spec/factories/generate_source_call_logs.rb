FactoryBot.define do
  factory :generate_source_call_log do
    user
    called_at { Time.current }
  end
end
