# テストで CSRF の合言葉を取る関数と、ログインする関数。
# テストでも CSRF 対策を有効にしているので、GET 以外を送るときは合言葉が要る（design/designs/技術構成.md の 3-3 D-1）。
# 合言葉は、本物の画面と同じ手順（GET /api/me を呼び、返ってきた Cookie を読む）で取る
module CsrfHelper
  # 合言葉を取る。未ログインなら /api/me は 401 だが、合言葉の Cookie は届く（API設計.md の 16-1-7）
  def csrf_token
    get "/api/me"
    # 画面側の decodeURIComponent と同じく、Cookie の値の符号化を戻す
    CGI.unescape(cookies[CsrfProtection::COOKIE_NAME])
  end

  # ログインする。ほかのテストの準備で使う
  def log_in_as(user, password: "password")
    post "/api/session",
         params: { email: user.email, password: password },
         headers: { "X-CSRF-Token" => csrf_token },
         as: :json
  end
end
