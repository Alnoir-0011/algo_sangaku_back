# 並べ替え形式の code_blocks をリクエストから受け取るコントローラ（作者向け・管理画面）が共有する処理（issue #278）。
# エラーの返し方は API ごとに異なる（作者向けはキー名付き、管理画面はエラー文の配列）ため、ここには含めない。
module Api::CodeBlocksParams
  extend ActiveSupport::Concern

  private

  # キーの有無で判定する。空の配列も「ブロックを 0 個にする」指定として扱い、構成の検証で弾く。
  def code_blocks_given?
    params.key?(:code_blocks)
  end

  # 大量の要素を送られてもメモリを使い切らないよう、ブロックを組み立てる前に件数だけを見て弾く。
  # 件数以外の構成の検証は、モデルの code_blocks_composition が行う。
  def too_many_code_blocks?
    blocks = params[:code_blocks]
    blocks.is_a?(Array) && blocks.size > ReorderSangaku::MAX_CODE_BLOCKS
  end

  # ReorderSangaku#save_with_code_blocks が受け取る、シンボルキーのハッシュ配列にする
  def code_blocks_params
    blocks = params.permit(code_blocks: %i[content correct_position])[:code_blocks]
    (blocks || []).map { |block| { content: block[:content], correct_position: block[:correct_position] } }
  end
end
