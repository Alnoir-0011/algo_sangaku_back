# コード記述形式の算額。PaizaIO でテストケースごとに採点する（issue #278）。
class CodeSangaku < ApplicationRecord
  include Sangakuable

  has_many :fixed_inputs, dependent: :destroy

  validates :source, presence: true, length: { maximum: 65_535 }

  validate :fixed_inputs_uniqueness

  # 親 sangaku・自身・fixed_inputs をまとめて保存する。
  # delegated_type では子が先に INSERT される必要があるため、自身 → 親 の順に保存する。
  def save_with_inputs(new_contents) # (str[] | nil) => boolean
    new_contents ||= []

    old_contents = self.fixed_inputs.pluck(:content)
    delete_contents = old_contents - new_contents
    add_contents = new_contents - old_contents
    add_inputs = add_contents.map { |content| self.fixed_inputs.build(content:) }

    inputs_invalid = add_inputs.map(&:invalid?).any?(true)
    # 親の title のエラーも同じ 400 にまとめて返せるよう、ここで検証しておく
    sangaku_invalid = sangaku.nil? || sangaku.invalid?

    return false if invalid? || inputs_invalid || sangaku_invalid

    ActiveRecord::Base.transaction do
      save!
      sangaku.save!
      fixed_inputs.where(content: delete_contents).destroy_all
      fixed_inputs << add_inputs
    end

    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  private

  def fixed_inputs_uniqueness
    content_ary = fixed_inputs.map(&:content)

    if content_ary.uniq.length != content_ary.length
      errors.add(:fixed_inputs, "が重複しています")
    end
  end
end
