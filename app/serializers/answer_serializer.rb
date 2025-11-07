class AnswerSerializer
  include JSONAPI::Serializer
  attributes :source
  attribute :status do |answer|
    results = answer.answer_results.map(&:status)
    results.include?("pending") ? "pending" :
      results.include?("incorrect") ? "incorrect" : "correct"
  end
  belongs_to :user_sangaku_save
  has_many :answer_results
end
