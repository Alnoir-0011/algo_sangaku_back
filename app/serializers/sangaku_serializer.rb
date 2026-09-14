class SangakuSerializer
  include JSONAPI::Serializer

  set_type :sangaku
  # description / difficulty は Sangaku から sangakuable へ delegate されている（issue #278）
  attributes :title, :description, :difficulty
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
