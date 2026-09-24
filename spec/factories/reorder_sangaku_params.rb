FactoryBot.define do
  # 並べ替え形式の作成 API に送る sangaku 部分のリクエストパラメータ用 factory。
  # code_sangaku 用の :sangaku_params と異なり source を持たない（issue #278）。
  factory :reorder_sangaku_params, class: Hash do
    skip_create
    initialize_with { attributes }

    title { "test_title" }
    description { "test_description" }
    difficulty { "easy" }
  end
end
