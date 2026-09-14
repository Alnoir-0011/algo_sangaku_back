# 出題形式ごとのテーブル（CodeSangaku / ReorderSangaku）が共通して持つ責務を集約する。
# 新しい出題形式を追加するときはこの concern を include する（issue #278）。
module Sangakuable
  extend ActiveSupport::Concern

  included do
    has_one :sangaku, as: :sangakuable, touch: true
    delegate :title, :user, :shrine, :user_id, :shrine_id, :created_at, :dedicate, to: :sangaku

    enum :difficulty,
         { easy: 0, normal: 10, difficult: 20, very_difficult: 30 },
         prefix: true

    validates :description, presence: true, length: { maximum: 65_535 }
    validates :difficulty, presence: true
  end
end
