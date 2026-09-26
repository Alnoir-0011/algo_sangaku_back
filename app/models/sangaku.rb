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

  # 神社に紐づく並べ替え算額のうち、回答数（正誤問わず）が最多のものを返す。
  # 同数の場合は created_at が古い方を優先する（新しい算額を後から量産して
  # 代表の座を奪う手口のコストを上げるため）。該当がなければ nil。
  # shrine が nil の場合は「未奉納の算額」にマッチしてしまわないよう nil を返す
  # （呼び出し側は sangaku.shrine（nil の可能性あり）をそのまま渡す想定のため）。
  #
  # 未認証で呼べる公開エンドポイント（Public::ReorderSangakusController 等）から
  # リクエストのたびに呼ばれるため、候補をメモリに展開せず SQL 側で集計する。
  def self.representative_reorder_for(shrine)
    return nil if shrine.nil?

    with_kind("reorder")
      .where(shrine: shrine)
      .left_joins(:answers)
      .group(:id)
      .order(Arel.sql("COUNT(answers.id) DESC, sangakus.created_at ASC"))
      .first
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
