# ログイン中のセッション。ログインするたびに1件でき、ログアウトで消える。
# Rails 8 の認証ジェネレーターのひな形と同じ形（design/designs/技術構成.md の 3-1）
class Session < ApplicationRecord
  belongs_to :user
end
