# 作者向けの1件分のレスポンス（GET /user/sangakus/:id、作成・更新・奉納など）用のシリアライザ。
# 一覧用の SangakuSerializer と異なり、code_blocks を含む（issue #278）。
class SangakuDetailSerializer
  include JSONAPI::Serializer
  include SangakuSerializerAttributes
  include OrderedCodeBlocksAttribute
end
