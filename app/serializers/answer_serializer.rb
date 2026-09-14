class AnswerSerializer
  include JSONAPI::Serializer
  attributes :source, :kind
  attribute :status do |answer|
    answer.status
  end
  belongs_to :user_sangaku_save
  # 実行結果は answerable が持つ。提出物を実行しない形式では空になる（issue #278）
  has_many :answer_results do |answer|
    answer.answerable.try(:answer_results) || []
  end
end
