# ① POST /api/session（ログイン）と ② DELETE /api/session（ログアウト）。
# 詳しくは design/designs/API設計.md の 16-1-5、16-3 ①②。
# Rails 8 の認証ジェネレーターのひな形と同じ形で書き、画面へ移動させる代わりに JSON を返している（技術構成.md の 3-1）
module Api
  class SessionsController < ApplicationController
    # ログインもログアウトも、ログイン前に使える
    allow_unauthenticated_access only: %i[create destroy]

    # ログインの回数制限：3分間に10回まで。IP アドレスごとに数える（ひな形と同じ。16-3 ①）
    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { render_error(:too_many_requests, I18n.t("api.errors.too_many_requests")) }

    # ① ログイン
    def create
      # メールアドレスで探し、パスワードを照合する。メールアドレスは User の normalizes で小文字にそろえてから探す。
      # 見つからないときも照合と同じくらいの時間をかけるので、登録されているかを時間から推測されない。
      # 送られてこなかった項目は空として扱い、同じ 401 にする
      user = User.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)

      if user
        start_new_session_for(user)
        @user = current_user
        @profile = current_company || current_student
        # 返事は形A。③ ログイン中の人と同じテンプレートを使う
        render "api/me/show", status: :ok
      else
        # どちらが違うかは出さない（権限_バリデーション.md の 17-3-1）
        render_error(:unauthorized, I18n.t("api.errors.login_failed"))
      end
    end

    # ② ログアウト。ログインしていなくても 204 を返す（何度押しても同じ結果にする。16-3 ②）
    def destroy
      terminate_session
      head :no_content
    end
  end
end
