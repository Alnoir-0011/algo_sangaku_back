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

    # バリデーションが子の関連（fixed_inputs / code_blocks）をロードしてキャッシュするため、
    # その後に外部で作られた子が dependent: :destroy の対象から漏れ、FK 違反になる。
    # 破棄の直前に has_many のキャッシュをすべて捨てて DB から読み直す。
    # prepend: true で、各形式が後から宣言する dependent: :destroy のコールバックより先に実行する。
    before_destroy :reset_has_many_caches, prepend: true
  end

  private

  def reset_has_many_caches
    self.class.reflect_on_all_associations(:has_many).each do |reflection|
      association(reflection.name).reset
    end
  end
end
