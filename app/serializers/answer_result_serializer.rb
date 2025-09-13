class AnswerResultSerializer
  include JSONAPI::Serializer
  attributes :status, :output

  attribute :fixed_input_content do |answer_result|
    answer_result.fixed_input.present? ? answer_result.fixed_input.content : ""
  end

  belongs_to :answer
  belongs_to :fixed_input
end
