# ④ POST /api/email_checks（メールアドレスの確認）。
# 新規登録のステップ1から進むときに、メールアドレスが使えるかを確かめる（全部入力した後にやり直しにならないように）。
# 詳しくは design/designs/API設計.md の 16-3 ④、権限_バリデーション.md の 17-3-1。
# 読むだけの処理だが POST にする。GET だとメールアドレスが URL に載り、サーバーの記録に残りやすいため
module Api
  class EmailChecksController < ApplicationController
    # ログイン前に使う
    allow_unauthenticated_access only: :create

    # 使えるメールアドレスなら 204（中身なし）。使えなければ 422 で、メールアドレスの誤りだけを返す
    def create
      # アカウントを組み立てて（保存しない）検証し、メールアドレスの誤り（空・形式・登録済み）だけを見る。
      # 判定はアカウントのモデルの決まりをそのまま使う（大文字や前後の空白をそろえてから比べるのも同じ）
      user = User.new(email: params[:email].to_s)
      user.validate
      messages = user.errors.full_messages_for(:email)

      if messages.empty?
        head :no_content
      else
        # パスワードの誤りなどは、ここでは返さない。確かめるのはメールアドレスだけ（16-3 ④）
        render_error(:unprocessable_content, I18n.t("api.errors.unprocessable"), errors: { email: messages })
      end
    end
  end
end
