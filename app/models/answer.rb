# 出題形式に依存しない部分を持つ共通テーブル（delegated_type の親）。
# 提出物や判定結果は answerable（CodeAnswer / ReorderAnswer）が持つ（issue #278）。
class Answer < ApplicationRecord
  class AlreadyAnsweredError < StandardError; end

  # 結果行の作成は answerable に委ねる。delegated_type では子が親より先に INSERT されるため、
  # 子の after_create の時点では親の行がなく user_sangaku_save をたどれない。
  after_create :create_answerable_results
  after_initialize :prevent_overwriting_existing_answer, if: :new_record?

  delegated_type :answerable, types: %w[CodeAnswer ReorderAnswer], dependent: :destroy

  belongs_to :user_sangaku_save

  # belongs_to の presence 検証は answerable が非 nil なら通ってしまうため、
  # 不正な子のまま親を INSERT して answerable_id が NULL になるのを防ぐ。
  # エラーは子の属性名のまま写し、400 のエラーキー（source など）を形式側の名前で返す。
  validate :answerable_must_be_valid

  delegate :status, to: :answerable

  # API で使う出題形式名と answerable_type の対応。形式を追加するときはここに足す（issue #278）
  KINDS = { "code" => "CodeAnswer", "reorder" => "ReorderAnswer" }.freeze

  # レスポンスで出題形式を判別するための識別子。
  # KINDS が delegated_type の全形式を含むことは spec で確かめている（足し忘れは本番ではなく CI で気づく）
  def kind
    KINDS.key(answerable_type)
  end

  # 各形式が持つ同名スコープを OR でまとめ、作者向けの結果が形式をまたいで合算されるようにする。
  # 形式の一覧は answerable_types から取るため、形式を追加してもこのスコープは変更しなくてよい。
  scope :status_correct, -> { answerable_condition(:status_correct) }
  scope :status_incorrect, -> { answerable_condition(:status_incorrect) }

  def self.answerable_condition(scope_name)
    answerable_types.map { |type|
      where(answerable_type: type, answerable_id: type.constantize.public_send(scope_name).select(:id))
    }.reduce(:or)
  end

  # 提出物を保存するかは形式の裁量のため、持たない形式では nil を返す。
  def source
    answerable.try(:source)
  end

  private

  def answerable_must_be_valid
    return if answerable.nil? || answerable.valid?

    answerable.errors.each { |error| errors.add(error.attribute, error.message) }
  end

  def prevent_overwriting_existing_answer
    return unless user_sangaku_save_id
    return unless self.class.exists?(user_sangaku_save_id: user_sangaku_save_id)

    raise AlreadyAnsweredError, "この算額にはすでに解答が存在します"
  end

  # 子から親への has_one は、この時点ではまだ解決できない（子が先に INSERT されるため）。
  # 自分自身を渡して、子が親をたどり直さずに済むようにする。
  def create_answerable_results
    answerable.create_results(self) if answerable.respond_to?(:create_results)
  end
end
