# Admin::SangakuSerializer と Admin::SangakuDetailSerializer で共通する属性定義（issue #278）。
# 作者向けの SangakuSerializerAttributes と同じく、継承ではなく Concern で共通化する。
module Admin::SangakuSerializerAttributes
  extend ActiveSupport::Concern

  included do
    # description / difficulty は Sangaku から sangakuable へ delegate されている（issue #278）
    attributes :title, :description, :difficulty, :created_at, :kind
    # source はコード記述形式固有の項目。並べ替え形式では nil を返す（issue #278）
    attribute :source do |sangaku|
      sangaku.code_sangaku? ? sangaku.sangakuable.source : nil
    end

    attribute :user_name do |sangaku|
      sangaku.user.nickname
    end

    attribute :shrine_name do |sangaku|
      sangaku.shrine&.name
    end
  end
end
