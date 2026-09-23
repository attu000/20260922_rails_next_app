# ログインの確認と、ログイン・ログアウトの部品。
# Django の認証のミドルウェアと @login_required にあたる。
# Rails 8 の認証ジェネレーターのひな形と同じ名前・形で書き、設計に合わせて直している（design/designs/技術構成.md の 3-1）。
# ひな形との違い：未ログインは画面へ移動させず 401 を返す／Cookie の Secure／ログアウトの冪等性／最終活動日／「今の会社」
module Authentication
  extend ActiveSupport::Concern

  included do
    # すべての窓口の前処理として、ログインを確かめる。
    # ApplicationController で CsrfProtection より後ろに差し込むので、CSRF の合言葉の Cookie を付けた後に動く
    before_action :require_authentication
  end

  class_methods do
    # ログイン前でも使える窓口は、これでログインの確認を外す（ログイン、ログアウト、存在しない URL など）
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  # ── ログインの確認 ──

  def require_authentication
    if resume_session
      record_last_active_on
    else
      # 前処理で返事を返すと、その後の処理（窓口の本体）は動かない。
      # ひな形では「ログイン画面へ移動」だが、画面は Next.js が受け持つので 401 を返す（API設計.md の 16-1-6）
      render_error(:unauthorized, I18n.t("api.errors.unauthorized"))
    end
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  # ── ログイン・ログアウトの部品（窓口から使う）──

  # ログインに成功したとき。sessions テーブルに1件作り、Cookie に署名付きのセッション番号を入れる
  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      # permanent：期限をとても長くする。ログインはログアウトするまで続く（API設計.md の 16-1-5）。
      # httponly：画面のプログラムから読めない。secure：本番のときだけ HTTPS に限る（技術構成.md の 3-1 A-1）
      cookies.signed.permanent[:session_id] = {
        value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production?
      }
    end
  end

  # ログアウトのとき。ログインしていなくても、何もせずに終わる（何度押しても同じ結果にする。16-3 ②）
  def terminate_session
    resume_session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end

  # ── 最終活動日（API設計.md の 16-1-12）──

  # 今日（日本時間）と、保存されている最終活動日が違うときだけ書き込む。その日の2回目以降は書き込まない。
  # update_column は、1つの列だけを直接書き換える（検証を通さず、更新日時も変えない）。
  # 最終活動日の記録は「プロフィールの更新」ではないので、更新日時を動かさない
  def record_last_active_on
    today = Time.zone.today
    current_user.update_column(:last_active_on, today) unless current_user.last_active_on == today
  end

  # ── 今ログインしている人（技術構成.md の 9-1）──
  # 「今の会社」「今の学生」を取り出す処理は、ここだけに書く。各所で current_user.company_profile と直接書かない。
  # 将来「1社に複数の担当者」にするとき、ここだけ直せば済むようにするため

  def current_user
    Current.user
  end

  def current_company
    current_user&.company_profile
  end

  def current_student
    current_user&.student_profile
  end
end
