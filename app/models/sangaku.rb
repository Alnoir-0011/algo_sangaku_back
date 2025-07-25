class Sangaku < ApplicationRecord
  belongs_to :user
  belongs_to :shrine, optional: true

  has_many :fixed_inputs, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 65_535 }
  validates :source, presence: true, length: { maximum: 65_535 }

  validate :fixed_inputs_uniqueness

  enum :difficulty,
        { easy: 0, nomal: 10, difficult: 20, very_difficult: 30 },
        prefix: true

  scope :title_contain, ->(title) { where("title LIKE ?", "%#{title}%") }

  def save_with_inputs(new_contents) # (str[] | nil) => boolean
    new_contents ||= []

    old_contents = self.fixed_inputs.pluck(:content)
    delete_contents = old_contents - new_contents
    add_contents = new_contents - old_contents
    add_inputs = add_contents.map { |content| self.fixed_inputs.build(content:) }

    inputs_invalid = add_inputs.map(&:invalid?).any?(true)

    return false if invalid? || inputs_invalid

    ActiveRecord::Base.transaction do
      save!
      fixed_inputs.where(content: delete_contents).destroy_all
      fixed_inputs << add_inputs
    end

    true
  rescue StandardError => e
    false
  end

  def self.search(params)
    relation = self.distinct
    return relation unless params

    if params[:shrine_id]
      shrine_id = params[:shrine_id].to_i != 0 ? params[:shrine_id].to_i : nil
      relation = relation.where(shrine_id: shrine_id)
    end

    words = params[:title].present? ? params[:title].split(nil) : []

    words.each do |word|
      relation = relation.title_contain(word)
    end

    relation
  end

  private

  def fixed_inputs_uniqueness
    content_ary = fixed_inputs.map(&:content)

    if content_ary.uniq.length != content_ary.length
      errors.add(:fixed_inputs, "が重複しています")
    end
  end
end
