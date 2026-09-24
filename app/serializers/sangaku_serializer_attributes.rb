# SangakuSerializer と SangakuDetailSerializer で共通する属性定義（issue #278）。
#
# jsonapi-serializer は `attributes` / `attribute` / `belongs_to` などの DSL で
# クラスごとに定義した内容を保持する。サブクラス化した場合にこれらが継承先へ
# 引き継がれるかは gem 内部の実装依存で未確認のため、継承ではなく Concern による
# 「同じ内容を両クラスで実行する」方式で共通化する。
module SangakuSerializerAttributes
  extend ActiveSupport::Concern

  included do
    set_type :sangaku
    # description / difficulty は Sangaku から sangakuable へ delegate されている（issue #278）
    attributes :title, :description, :difficulty, :kind
    # source / inputs はコード記述形式固有の項目。並べ替え形式には存在しないため
    # 形式で分岐し、並べ替え形式では nil / 空配列を返す（issue #278）。
    attribute :source do |sangaku|
      sangaku.code_sangaku? ? sangaku.sangakuable.source : nil
    end
    attribute :inputs do |sangaku|
      next [] unless sangaku.code_sangaku?

      inputs = sangaku.sangakuable.fixed_inputs
      inputs.map { |input| { id: input.id, content: input.content } }
    end
    attribute :author_name do |sangaku|
      sangaku.user.nickname
    end

    attribute :shrine_name do |sangaku|
      sangaku.shrine&.name
    end

    belongs_to :user
    belongs_to :shrine
  end
end
