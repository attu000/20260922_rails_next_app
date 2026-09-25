require "rails_helper"

# ⑰ POST /api/student/profile/icon（学生のアイコン）のテスト。
# 中身は企業のアイコン（⑩）と共通（app/controllers/concerns/icon_upload.rb）なので、細かい確認（2MB、ファイルなし）は
# spec/requests/api/company/profile_icons_spec.rb に任せ、ここでは学生の窓口につながっているかを確かめる。
# 詳しくは design/designs/API設計.md の 16-3 ⑰、技術構成.md の 9-3
RSpec.describe "学生のアイコン（POST /api/student/profile/icon）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:profile) { student_user.student_profile }

  # アイコンを送る。ファイルを params に入れると multipart/form-data で送られる。合言葉も付ける
  def post_icon(params)
    post "/api/student/profile/icon", params: params, headers: { "X-CSRF-Token" => csrf_token }
  end

  describe "学生のとき" do
    before { log_in_as(student_user) }

    it "PNG を保存でき、icon_url を返す。/api/me（形A）と⑮ 表示にも同じものが入る" do
      post_icon(icon: png_upload)

      expect(response).to have_http_status(:ok)
      icon_url = response.parsed_body["icon_url"]
      expect(icon_url).to start_with("/rails/active_storage/")

      get "/api/me"
      expect(response.parsed_body["icon_url"]).to eq(icon_url)

      get "/api/student/profile"
      expect(response.parsed_body["icon_url"]).to eq(icon_url)
    end

    it "中身が GIF なら、名前が .png でも 422（形式はファイルの中身から判定する）" do
      post_icon(icon: gif_disguised_as_png_upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["icon"]).to eq([ "アイコンはPNG・JPEG・WebPのいずれかにしてください" ])
      expect(profile.reload.icon).not_to be_attached
    end
  end

  it "企業なら 403" do
    log_in_as(create(:company_user))

    post_icon(icon: png_upload)

    expect(response).to have_http_status(:forbidden)
  end
end
