# 「今のリクエストのセッション」を覚えておく入れ物。リクエストが終わると自動で空になる。
# Current.user で今ログインしている人を取り出せる（Django の request.user のような役割）。
# Rails 8 の認証ジェネレーターのひな形と同じ形（design/designs/技術構成.md の 3-1）
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
