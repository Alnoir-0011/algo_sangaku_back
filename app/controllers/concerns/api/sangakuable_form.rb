# 出題形式ごとの作成・更新コントローラ（CodeSangakus / ReorderSangakus）が共有する処理（issue #278）。
# include するコントローラは、形式ごとに permit する項目を返す sangaku_params を定義すること。
module Api::SangakuableForm
  extend ActiveSupport::Concern

  private

  # :id は親 sangakus.id。形式は作成後に変更できないため、別形式の id には 404 を返す。
  # kind には delegated_type の述語名（:code_sangaku / :reorder_sangaku）を渡す。
  def find_own_sangakuable!(kind)
    sangaku = current_user.sangakus.find(params[:id])
    raise ActiveRecord::RecordNotFound unless sangaku.public_send("#{kind}?")

    sangaku.sangakuable
  end

  # title は親、それ以外（description / difficulty / 形式固有の項目）は形式固有テーブルが持つ
  def parent_params
    sangaku_params.slice(:title)
  end

  def sangakuable_params
    sangaku_params.except(:title)
  end

  # front は項目ごとのエラー表示にキー名を使うため、親と子のエラーを一つにまとめて返す
  def merged_errors(sangakuable)
    parent_errors = sangakuable.sangaku&.errors&.messages || {}
    parent_errors.merge(sangakuable.errors.messages)
  end
end
