class AnswerSerializer
  include JSONAPI::Serializer
  attributes :source
  attribute :status do |answer|
    answer.status
  end
  belongs_to :user_sangaku_save
  has_many :answer_results
end
