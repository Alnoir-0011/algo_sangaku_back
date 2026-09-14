# 解答者向けの一覧（GET /shrines/:shrine_id/sangakus、GET /user/saved_sangakus）と保存 API 用のシリアライザ。
# 件数分の code_blocks を含めると重くなるため、code_blocks は持たない（issue #278）。
class PublicSangakuSerializer
  include JSONAPI::Serializer
  include PublicSangakuSerializerAttributes
end
