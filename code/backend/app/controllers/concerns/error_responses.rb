# エラーの返事の形をそろえる。どの窓口でも {"message": "…", "errors": {…}} の形で返す。
# Django REST framework の exception_handler や、get_object_or_404 が 404 を返す仕組みにあたる。
# 詳しくは design/designs/API設計.md の 16-1-10
module ErrorResponses
  extend ActiveSupport::Concern

  included do
    # 想定外のエラーは、本番のときだけこの形に包む。
    # 開発中とテストでは、原因を調べやすいよう、Rails の詳しいエラー表示のままにする。
    # rescue_from は後に書いたものが先に効くので、いちばん広い StandardError を最初に書く
    rescue_from StandardError, with: :render_internal_server_error if Rails.env.production?

    # 探したデータがない。見てよい範囲の中から探して見つからない場合も、これで 404 になる（16-1-10）
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    # 今の状態ではできない操作（応募済みの募集への応募など）。モデルの処理が投げる（app/errors/conflict_error.rb）
    rescue_from ConflictError, with: :render_conflict
    # CSRF の合言葉がない・違う
    rescue_from ActionController::InvalidAuthenticityToken, with: :render_forbidden
    # モデルの検証に通らなかった（save! など）
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    # 必須のパラメータがない（params.require で見つからない）
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  end

  private

  # すべてのエラーの返事は、ここを通す。
  # errors は 422 のときだけ付ける（項目ごとの理由。画面は各項目の下に出す）
  def render_error(status, message, errors: nil)
    body = { message: message }
    body[:errors] = errors if errors
    render json: body, status: status
  end

  def render_not_found(_exception = nil)
    render_error(:not_found, I18n.t("api.errors.not_found"))
  end

  def render_forbidden(_exception = nil)
    render_error(:forbidden, I18n.t("api.errors.forbidden"))
  end

  # 今の状態ではできない（409）。項目ごとではなく、全体に1行だけ出す（権限_バリデーション.md の 17-3-6）。
  # 画面は、この返事を受けたら最新の状態を読み直す
  def render_conflict(_exception = nil)
    render_error(:conflict, I18n.t("api.errors.conflict"))
  end

  # 入力の誤り（422）。各窓口からは、モデルの errors を渡して呼ぶ。
  # 項目ごとの理由は「メールアドレスを入力してください」のように、項目名付きの文にする（17-3-6）
  def render_unprocessable(errors)
    render_error(:unprocessable_content, I18n.t("api.errors.unprocessable"), errors: errors.to_hash(true))
  end

  def render_record_invalid(exception)
    render_unprocessable(exception.record.errors)
  end

  def render_parameter_missing(exception)
    message = I18n.t("errors.format", attribute: exception.param, message: I18n.t("errors.messages.blank"))
    render_error(:unprocessable_content, I18n.t("api.errors.unprocessable"), errors: { exception.param => [ message ] })
  end

  def render_internal_server_error(exception)
    logger.error(exception.full_message(highlight: false))
    render_error(:internal_server_error, I18n.t("api.errors.internal_server_error"))
  end
end
