# 詳細・更新・削除（GET/PATCH/DELETE /admin/sangakus/:id）用のシリアライザ。
# 一覧用の Admin::SangakuSerializer と異なり、code_blocks を含む（issue #278）。
class Admin::SangakuDetailSerializer
  include JSONAPI::Serializer
  include Admin::SangakuSerializerAttributes
  include OrderedCodeBlocksAttribute
end
