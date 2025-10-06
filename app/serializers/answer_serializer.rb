class AnswerSerializer
  include JSONAPI::Serializer
  attributes :source
  attribute :status do |answer|
    results = answer.answer_results.map(&:status)
    return "pending" if results.include?("pending")

    results.include?("incorrect") ? "incorrect" : "correct"
  end
  belongs_to :user_sangaku_save
  has_many :answer_results
end
