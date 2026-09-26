# ページ分けする一覧の "pagination" の部品（design/designs/API設計.md の 16-1-11）。
# 使い方：json.partial! "api/shared/pagination", pagy: @pagy
# 検索の窓口（⑱ 募集検索・㉒ 学生検索）だけは、条件に合う件数も渡す：
#   json.partial! "api/shared/pagination", pagy: @pagy, matched_count: 件数

json.pagination do
  json.page pagy.page
  json.per_page pagy.limit
  json.total_count pagy.count
  json.matched_count local_assigns[:matched_count] if local_assigns.key?(:matched_count)
  json.total_pages pagy.last
end
