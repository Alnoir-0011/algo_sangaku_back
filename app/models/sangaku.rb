# 出題形式に依存しない部分を持つ共通テーブル（delegated_type の親）。
# 形式固有のカラムは sangakuable（CodeSangaku / ReorderSangaku）が持つ（issue #278）。
class Sangaku < ApplicationRecord
  include SphericalCosineTheorem

  DEFAULT_DEDICATE_DISTANCE = 0.1 # km

  delegated_type :sangakuable, types: %w[CodeSangaku ReorderSangaku], dependent: :destroy

  belongs_to :user
  belongs_to :shrine, optional: true

  has_many :user_sangaku_saves, dependent: :destroy, class_name: "UserSangakuSave"
  has_many :saved_by_users, through: :user_sangaku_saves, source: :user
  has_many :answers, through: :user_sangaku_saves

  validates :title, presence: true, length: { maximum: 255 }

  delegate :description, :difficulty, to: :sangakuable

  # API で使う出題形式名と sangakuable_type の対応。形式を追加するときはここに足す（issue #278）
  KINDS = { "code" => "CodeSangaku", "reorder" => "ReorderSangaku" }.freeze

  # レスポンスで出題形式を判別するための識別子。
  # KINDS が delegated_type の全形式を含むことは spec で確かめている（足し忘れは本番ではなく CI で気づく）
  def kind
    KINDS.key(sangakuable_type)
  end

  scope :title_contain, ->(title) { where("title LIKE ?", "%#{sanitize_sql_like(title)}%") }

  # kind（"code" / "reorder"）で出題形式を絞り込む。KINDS のキーで判定するため、
  # 形式を追加してもこのスコープは変更しなくてよい。
  scope :with_kind, ->(kind) {
    KINDS.key?(kind) ? where(sangakuable_type: KINDS[kind]) : all
  }

  # difficulty は形式固有テーブルにあるため、形式ごとの子テーブルを横断して絞り込む。
  # 形式の一覧は delegated_type が生成する sangakuable_types から取るので、
  # 形式を追加してもこのスコープは変更しなくてよい。
  scope :with_difficulty, ->(difficulty) {
    where(id: sangakuable_types.map { |type|
      Sangaku.where(sangakuable_type: type, sangakuable_id: type.constantize.where(difficulty:).select(:id)).select(:id)
    }.reduce { |left, right| left.or(right) })
  }

  # 形式をまたいで有効な難易度名の一覧。
  def self.difficulty_names
    sangakuable_types.flat_map { |type| type.constantize.difficulties.keys }.uniq
  end

  def self.search(params)
    relation = self.distinct
    return relation unless params

    if params[:shrine_id]
      if params[:shrine_id] == "any"
        relation = relation.where.not(shrine_id: nil)
      else
        shrine_id = params[:shrine_id].to_i != 0 ? params[:shrine_id].to_i : nil
        relation = relation.where(shrine_id: shrine_id)
      end
    end

    if params[:difficulty] && difficulty_names.include?(params[:difficulty])
      relation = relation.with_difficulty(params[:difficulty])
    end

    if params[:kind]
      relation = relation.with_kind(params[:kind])
    end

    words = params[:title].present? ? params[:title].split(nil) : []

    words.each do |word|
      relation = relation.title_contain(word)
    end

    relation
  end

  # lat/lng はクライアント申告値であり、位置偽装のセキュリティ境界にはならない。
  # 個人開発規模のなりすましリスクを踏まえ、署名済み位置情報やレート制限の追加対応は不要と判断した（issue #312）。
  def dedicate(new_shrine, lat, lng)
    return false if shrine.present? || distance(new_shrine, lat, lng) > DEFAULT_DEDICATE_DISTANCE

    self.shrine = new_shrine
    save!
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
