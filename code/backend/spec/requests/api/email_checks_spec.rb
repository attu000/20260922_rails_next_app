require "rails_helper"

# ④ POST /api/email_checks（メールアドレスの確認）のテスト。
# 詳しくは design/designs/API設計.md の 16-3 ④、権限_バリデーション.md の 17-3-1
RSpec.describe "メールアドレスの確認（/api/email_checks）", type: :request do
  # 確かめる。ログイン前の画面から呼ぶので、ログインはしない。CSRF 対策は有効なので、合言葉を付ける
  def check_email(email)
    post "/api/email_checks", params: { email: email }, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  it "ログインしていなくても使える。まだ使われていないメールアドレスなら 204" do
    check_email("new@example.com")

    expect(response).to have_http_status(:no_content)
  end

  it "登録済みなら 422。「メールアドレスはすでに登録されています」" do
    create(:company_user, email: "taken@example.com")

    check_email("taken@example.com")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]).to eq("email" => [ "メールアドレスはすでに登録されています" ])
  end

  it "大文字や前後の空白が違っても、登録済みとして扱う（保存するときと同じくそろえてから比べる）" do
    create(:student_user, email: "taken@example.com")

    check_email("  Taken@Example.COM ")

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "形式が違えば 422。返す誤りはメールアドレスだけ（パスワードの誤りなどは返さない）" do
    check_email("not-an-email")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].keys).to eq([ "email" ])
  end

  it "空なら 422。「メールアドレスを入力してください」を含む" do
    check_email("")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]["email"]).to include("メールアドレスを入力してください")
  end
end
