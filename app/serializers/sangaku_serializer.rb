# 一覧（GET /user/sangakus）用のシリアライザ。
# 件数分の code_blocks を含めると重くなるため、code_blocks は持たない（issue #278）。
class SangakuSerializer
  include JSONAPI::Serializer
  include SangakuSerializerAttributes
end
