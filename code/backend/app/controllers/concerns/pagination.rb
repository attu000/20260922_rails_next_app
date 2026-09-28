# 一覧のページ分けを、ここ1か所にまとめる（design/designs/API設計.md の 16-1-11・16-1-14）。
# 部品は Pagy。データベースの結果（SQL で並べたもの）を分ける。おすすめ順も、上位の並びを SQL の並べ替えに入れて
# データベースで並べるので、同じ通り道になる（技術構成.md の 9-1-1 の2。PR295）。Pagy は Ruby の配列も分けられる。
# Django の Paginator(queryset, 20).get_page(request.GET.get("page")) にあたる
module Pagination
  extend ActiveSupport::Concern
  include Pagy::Method

  # 1ページの件数。利用者は変えられない（16-1-11）
  PER_PAGE = 20

  private

  # 一覧を受け取り、[ページの情報, そのページの行] の2つを返す。
  # ページ番号は ?page= から Pagy が読む
  def paginate(collection)
    pagy(:offset, collection, limit: PER_PAGE)
  end

  # 分けたページの行に、関連するデータ（会社、アイコンなど）をまとめて読み込み、配列で返す。
  # 1行ごとに問い合わせが増える N+1問題を避けるため。取り出したあとの行にかける。
  # Django の prefetch_related_objects(行の一覧, *関連) にあたる
  def preload_records(records, associations)
    records = records.to_a
    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
    records
  end
end
