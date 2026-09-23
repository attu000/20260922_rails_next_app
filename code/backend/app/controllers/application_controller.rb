# すべての API の親。共通の仕組みをここで差し込む。
# - ErrorResponses：エラーの返事の形をそろえる（API設計.md の 16-1-10）
# - CsrfProtection：CSRF 対策（API設計.md の 16-1-7）
class ApplicationController < ActionController::API
  include ErrorResponses
  include CsrfProtection
end
