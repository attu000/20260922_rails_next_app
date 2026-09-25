require "rails_helper"

# ③ GET /api/me（ログイン中の人）のテスト。
# 詳しくは design/designs/API設計.md の 16-1-5・16-1-12、16-3 ③、形A（16-3-2）
RSpec.describe "ログイン中の人（GET /api/me）", type: :request do
  it "未ログインなら 401" do
    get "/api/me"

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["message"]).to eq("ログインしてください")
  end

  it "企業なら形A を返す" do
    user = create(:company_user)
    log_in_as(user)

    get "/api/me"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "id" => user.id,
      "role" => "company",
      "name" => "株式会社テスト",
      "icon_url" => nil,
      "unread_notifications_count" => nil
    )
  end

  it "企業にアイコンがあれば、icon_url にその URL が入る" do
    user = create(:company_user)
    user.company_profile.icon.attach(
      io: StringIO.new(UploadHelper::PNG_BYTES), filename: "icon.png", content_type: "image/png"
    )
    log_in_as(user)

    get "/api/me"

    expect(response.parsed_body["icon_url"]).to start_with("/rails/active_storage/")
  end

  it "学生なら形A を返す" do
    user = create(:student_user)
    log_in_as(user)

    get "/api/me"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["role"]).to eq("student")
    expect(response.parsed_body["name"]).to eq("テスト 太郎")
  end

  it "呼ぶと最終活動日が今日になる" do
    user = create(:company_user)
    user.update_column(:last_active_on, Time.zone.today - 3)
    # ログインの窓口そのものは、最終活動日を記録しない（ログインの確認を外しているため）
    log_in_as(user)

    get "/api/me"

    # 日本時間の今日（API設計.md の 16-1-12）
    expect(user.reload.last_active_on).to eq(Time.zone.today)
  end
end
