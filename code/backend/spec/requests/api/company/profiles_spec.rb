require "rails_helper"

# ⑧ GET /api/company/profile（表示）と ⑨ PATCH /api/company/profile（保存）、種別の入口の確認のテスト。
# 詳しくは design/designs/API設計.md の 16-1-6・16-1-10、16-3 ⑧⑨、権限_バリデーション.md の 17-3-4
RSpec.describe "企業のプロフィール（/api/company/profile）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:profile) { company_user.company_profile }
  let!(:industry_a) { create(:industry) }
  let!(:industry_b) { create(:industry) }
  let!(:business_type_a) { create(:business_type) }

  # 保存を送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def patch_profile(params)
    patch "/api/company/profile", params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      get "/api/company/profile"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["message"]).to eq("ログインしてください")
    end

    it "学生なら、表示は 403" do
      log_in_as(create(:student_user))

      get "/api/company/profile"

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["message"]).to eq("この操作はできません")
    end

    it "学生なら、保存も 403" do
      log_in_as(create(:student_user))

      patch_profile(name: "書き換え")

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "⑧ 表示" do
    it "自社のプロフィールを、決めた形で返す" do
      profile.update!(about: "テストの会社です", employee_size: :size_10_49)
      profile.industries << industry_a
      log_in_as(company_user)

      get "/api/company/profile"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly(
        "name", "industry_ids", "business_type_ids", "employee_size", "business_description", "about", "icon_url"
      )
      expect(body["name"]).to eq("株式会社テスト")
      expect(body["industry_ids"]).to eq([ industry_a.id ])
      expect(body["employee_size"]).to eq("size_10_49")
      expect(body["about"]).to eq("テストの会社です")
      expect(body["icon_url"]).to be_nil
    end
  end

  describe "⑨ 保存" do
    before { log_in_as(company_user) }

    it "保存でき、⑧と同じ形で返す。業界は送った一覧に置き換わる" do
      profile.industries << industry_a

      patch_profile(
        name: "株式会社新しい名前",
        about: "新しい説明",
        employee_size: "size_50_99",
        industry_ids: [ industry_b.id ],
        business_type_ids: [ business_type_a.id ]
      )

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["industry_ids"]).to eq([ industry_b.id ])
      profile.reload
      expect(profile.name).to eq("株式会社新しい名前")
      expect(profile.employee_size).to eq("size_50_99")
      expect(profile.industry_ids).to eq([ industry_b.id ])
      expect(profile.business_type_ids).to eq([ business_type_a.id ])
    end

    it "会社名だけで保存できる（ほかは任意。その他決め事.md の 5-9）" do
      patch_profile(name: "株式会社テスト", about: "", business_description: "", employee_size: nil,
                    industry_ids: [], business_type_ids: [])

      expect(response).to have_http_status(:ok)
    end

    it "会社名が空欄なら 422。業界も変わらない（先に確かめてから、トランザクションで書き込むため）" do
      profile.industries << industry_a

      patch_profile(name: "", industry_ids: [ industry_b.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["name"]).to eq([ "会社名を入力してください" ])
      expect(profile.reload.industry_ids).to eq([ industry_a.id ])
    end

    it "存在しない業界の番号なら、404 ではなく 422" do
      patch_profile(name: "株式会社テスト", industry_ids: [ 0 ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["industry_ids"]).to eq([ "業界に選べない値が含まれています" ])
    end

    it "同じ番号が重複していたら 422" do
      patch_profile(name: "株式会社テスト", industry_ids: [ industry_a.id, industry_a.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["industry_ids"]).to eq([ "業界に同じ値が重複しています" ])
    end

    it "人数が選択肢にない値なら 422" do
      patch_profile(name: "株式会社テスト", employee_size: "size_999")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("employee_size")
    end

    it "長すぎる文章なら 422（2,000文字まで）" do
      patch_profile(name: "株式会社テスト", about: "あ" * 2001)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("about")
    end
  end
end
