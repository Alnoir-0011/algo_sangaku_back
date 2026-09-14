class AnswerResultSerializer
  include JSONAPI::Serializer
  attributes :status, :output

  attribute :fixed_input_content do |answer_result|
    answer_result.fixed_input.present? ? answer_result.fixed_input.content : ""
  end

  # answer_id 列は code_answer_id へ付け替えたが、レスポンス上の関連名は answer のまま保つ
  # （front の型との互換のため）。ブロックを渡すと関連 id が <name>_id ではなく id で解決される。
  belongs_to :answer do |answer_result|
    answer_result.answer
  end
  belongs_to :fixed_input
end
