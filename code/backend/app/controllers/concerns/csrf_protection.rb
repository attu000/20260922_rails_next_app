# CSRF（なりすまし送信）対策。
# Django の CsrfViewMiddleware と @ensure_csrf_cookie にあたる。
# 詳しくは design/designs/API設計.md の 16-1-7
module CsrfProtection
  extend ActiveSupport::Concern

  # 合言葉を画面に渡す Cookie の名前。
  # 画面側（Next.js）はここから読み、GET 以外を送るときに X-CSRF-Token ヘッダーに入れて送り返す
  COOKIE_NAME = "CSRF-TOKEN".freeze

  included do
    # API モードのコントローラーには、Cookie と CSRF 対策の機能が入っていないので足す
    include ActionController::Cookies
    include ActionController::RequestForgeryProtection

    # 合言葉の Cookie は、合言葉の確認やログインの確認より「前」に付ける。
    # 前処理で付けた Cookie は、あとの前処理で断られても返事に載るので、401・403 の返事にも付く。
    # 後処理（after_action）で付けると、断った返事に付かず、ログイン画面から誰もログインできなくなる
    before_action :set_csrf_cookie

    # GET 以外の送信で、X-CSRF-Token ヘッダーの合言葉を確かめる。
    # 違えば例外になり、ErrorResponses が 403 で返す
    protect_from_forgery with: :exception
  end

  private

  def set_csrf_cookie
    cookies[COOKIE_NAME] = {
      value: form_authenticity_token,
      same_site: :lax,
      secure: Rails.env.production?
      # httponly は付けない。画面のプログラムから読めるようにするため（ログイン用の Cookie は読めないまま）
    }
  end
end
