FactoryBot.define do
  factory :fixed_input do
    sequence(:content) { |n| "test_input_#{n}" }

    # 既存 spec の create(:fixed_input, sangaku: sangaku) をそのまま使えるようにする。
    # sangaku を渡した場合はその sangakuable にぶら下げる。
    transient do
      sangaku { nil }
    end

    code_sangaku { sangaku ? sangaku.sangakuable : association(:code_sangaku) }
  end
end
