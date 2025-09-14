class AnswerSerializer
  include JSONAPI::Serializer
  attributes :source
  belongs_to :user_sangaku_save
  has_many :answer_results
end
