FactoryBot.define do
  factory :shrine do
    name { "test_shrine" }
    address { "test_address" }
    latitude { 35.70204829610801 }
    longitude { 139.76789333814216 }
    sequence(:place_id) { |n| "test_place_id_#{n}" }
  end
end
