FactoryBot.define do
  # 作成・更新 API に送るリクエストパラメータ用の factory。
  # 親（title）と形式固有（description / source / difficulty）が別テーブルに分かれた後も、
  # request spec が 1 つのハッシュとしてフォーム項目を組み立てられるようにする（issue #278）。
  factory :sangaku_params, class: Hash do
    skip_create
    initialize_with { attributes }

    title { "test_title" }
    description { "test_description" }
    source { "puts 'Hello world'" }
    difficulty { "easy" }
  end
end
