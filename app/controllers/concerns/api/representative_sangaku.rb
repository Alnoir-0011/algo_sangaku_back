# 公開エンドポイント（GET /public/reorder_sangakus/:id、POST /public/reorder_sangakus/:id/answer）が
# 共有する判定ロジック（issue #359）。URLで指定された sangaku が、
# 神社ごとにただ一つ存在する「代表並べ替え問題」であるかどうかを判定する。
module Api::RepresentativeSangaku
  extend ActiveSupport::Concern

  private

  # 並べ替え問題であり、かつその神社の代表算額（Sangaku.representative_reorder_for）と
  # 一致する場合のみ true を返す。代表以外の並べ替え問題IDが指定された場合は false となり、
  # 呼び出し元コントローラが 403 を返す。
  def representative?(sangaku)
    sangaku.reorder_sangaku? && Sangaku.representative_reorder_for(sangaku.shrine) == sangaku
  end
end
