require "rails_helper"

# ⑩ POST /api/company/profile/icon（企業のアイコン）のテスト。
# 詳しくは design/designs/API設計.md の 16-3 ⑩、技術構成.md の 9-3
RSpec.describe "企業のアイコン（POST /api/company/profile/icon）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:profile) { company_user.company_profile }

  # アイコンを送る。ファイルを params に入れると multipart/form-data で送られる。合言葉も付ける
  def post_icon(params)
    post "/api/company/profile/icon", params: params, headers: { "X-CSRF-Token" => csrf_token }
  end

  describe "企業のとき" do
    before { log_in_as(company_user) }

    it "PNG を保存でき、icon_url を返す。/api/me（形A）にも同じものが入る" do
      post_icon(icon: png_upload)

      expect(response).to have_http_status(:ok)
      icon_url = response.parsed_body["icon_url"]
      expect(icon_url).to start_with("/rails/active_storage/")

      get "/api/me"
      expect(response.parsed_body["icon_url"]).to eq(icon_url)
    end

    it "差し替えられる。付いているアイコンは1つだけ" do
      post_icon(icon: png_upload)
      first_url = response.parsed_body["icon_url"]

      post_icon(icon: png_upload)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["icon_url"]).not_to eq(first_url)
      expect(ActiveStorage::Attachment.where(record: profile, name: "icon").count).to eq(1)
    end

    it "中身が GIF なら、名前が .png でも 422（形式はファイルの中身から判定する）" do
      post_icon(icon: gif_disguised_as_png_upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["icon"]).to eq([ "アイコンはPNG・JPEG・WebPのいずれかにしてください" ])
      expect(profile.reload.icon).not_to be_attached
    end

    it "2MB を超えたら 422" do
      post_icon(icon: too_large_png_upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["icon"]).to eq([ "アイコンは2MB以下にしてください" ])
      expect(profile.reload.icon).not_to be_attached
    end

    it "ファイルがなければ 422" do
      post_icon({})

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("icon")
    end
  end

  it "学生なら 403" do
    log_in_as(create(:student_user))

    post_icon(icon: png_upload)

    expect(response).to have_http_status(:forbidden)
  end
end
