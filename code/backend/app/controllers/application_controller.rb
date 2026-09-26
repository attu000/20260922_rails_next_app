# すべての API の親。共通の仕組みをここで差し込む。
# - ErrorResponses：エラーの返事の形をそろえる（API設計.md の 16-1-10）
# - CsrfProtection：CSRF 対策（API設計.md の 16-1-7）
# - Authentication：ログインの確認（API設計.md の 16-1-6）
# - Pagination：一覧のページ分け（API設計.md の 16-1-11）。前処理はないので、差し込む順番に関係しない
#
# 差し込む順番が、前処理の動く順番になる。必ずこの順にする。
#   1. CSRF の合言葉の Cookie を付ける  2. 合言葉を確かめる（だめなら 403）  3. ログインを確かめる（だめなら 401）
# 1 が先に動くので、3 で断った 401 の返事にも合言葉が付く。
# 逆にすると、ログイン画面を初めて開いた人が合言葉を受け取れず、誰もログインできなくなる
class ApplicationController < ActionController::API
  include ErrorResponses
  include CsrfProtection
  include Authentication
  include Pagination
end
