# PublicSangakuSerializer と PublicSangakuDetailSerializer で共通する属性定義（issue #278）。
# 作者向けの SangakuSerializerAttributes と同じく、継承ではなく Concern で共通化する。
module PublicSangakuSerializerAttributes
  extend ActiveSupport::Concern

  included do
    set_type :sangaku
    # description / difficulty は Sangaku から sangakuable へ delegate されている（issue #278）
    attributes :title, :description, :difficulty, :kind
    # inputs はコード記述形式固有の項目。並べ替え形式では空配列を返す（issue #278）
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
