require "rails_helper"

# ① POST /api/session（ログイン）と ② DELETE /api/session（ログアウト）のテスト。
# 詳しくは design/designs/API設計.md の 16-1-5・16-1-7、16-3 ①②
RSpec.describe "ログインとログアウト（/api/session）", type: :request do
  let!(:company_user) { create(:company_user) }

  describe "① ログイン（POST /api/session）" do
    # CLAUDE.md で必須とされているテスト（技術構成.md の 3-3 D-1）。
    # 合言葉の Cookie を後処理で付けると、未ログインの 401 に付かず、ここで失敗する
    it "ログイン画面を初めて開いた人が、そのままログインできる" do
      # ログイン画面を開いたときと同じく、未ログインで /api/me を呼ぶ
      get "/api/me"
      expect(response).to have_http_status(:unauthorized)
      # 401 の返事にも、合言葉の Cookie が付いている
      token = cookies[CsrfProtection::COOKIE_NAME]
      expect(token).to be_present

      # その合言葉でログインできる
      post "/api/session",
           params: { email: company_user.email, password: "password" },
           headers: { "X-CSRF-Token" => CGI.unescape(token) },
           as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["role"]).to eq("company")

      # ログインした状態になっている
      get "/api/me"
      expect(response).to have_http_status(:ok)
    end

    it "合言葉なしのログインは 403" do
      post "/api/session", params: { email: company_user.email, password: "password" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["message"]).to eq("この操作はできません")
    end

    it "パスワードが違うと 401" do
      log_in_as(company_user, password: "wrong-password")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["message"]).to eq("ログインができません")
    end

    # どちらが違うかを出さない（権限_バリデーション.md の 17-3-1）
    it "登録されていないメールアドレスでも、同じ 401" do
      post "/api/session",
           params: { email: "nobody@example.com", password: "password" },
           headers: { "X-CSRF-Token" => csrf_token },
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["message"]).to eq("ログインができません")
    end

    it "メールアドレスの大文字・小文字が違ってもログインできる" do
      post "/api/session",
           params: { email: company_user.email.upcase, password: "password" },
           headers: { "X-CSRF-Token" => csrf_token },
           as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "② ログアウト（DELETE /api/session）" do
    it "ログアウトすると、ログイン中の人が 401 になる" do
      log_in_as(company_user)

      delete "/api/session", headers: { "X-CSRF-Token" => csrf_token }
      expect(response).to have_http_status(:no_content)

      get "/api/me"
      expect(response).to have_http_status(:unauthorized)
    end

    # 何度押しても同じ結果にする（16-3 ②）
    it "ログインしていなくても、ログアウトは 204" do
      delete "/api/session", headers: { "X-CSRF-Token" => csrf_token }

      expect(response).to have_http_status(:no_content)
    end
  end
end
