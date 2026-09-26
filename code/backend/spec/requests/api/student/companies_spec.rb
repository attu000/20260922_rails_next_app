require "rails_helper"

# ⑳ 企業詳細と、種別の入口の確認のテスト。
# 学生はすべての企業を見られるので、「見てよい範囲の外」は存在しない番号だけ（API設計.md の 16-1-10）。
# 詳しくは design/designs/API設計.md の 16-3 ⑳
RSpec.describe "学生から見た企業詳細（/api/student/companies/:id）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:company) { create(:company_user).company_profile }

  describe "種別の入口の確認（16-1-6）" do
    it "企業なら 403" do
      log_in_as(create(:company_user))

      get "/api/student/companies/#{company.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "⑳ 企業詳細" do
    before { log_in_as(student_user) }

    it "企業プロフィールを、決めた形で返す。業界・事業形態は企業プロフィールの値" do
      industry = create(:industry)
      business_type = create(:business_type)
      company.update_profile(
        name: "株式会社サンプル", employee_size: "size_10_49", about: "会社の紹介",
        industry_ids: [ industry.id ], business_type_ids: [ business_type.id ]
      )

      get "/api/student/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly(
        "id", "name", "industry_ids", "business_type_ids", "employee_size",
        "business_description", "about", "icon_url", "job_postings"
      )
      expect(body).to include(
        "id" => company.id,
        "name" => "株式会社サンプル",
        "industry_ids" => [ industry.id ],
        "business_type_ids" => [ business_type.id ],
        "employee_size" => "size_10_49",
        "business_description" => nil,
        "about" => "会社の紹介",
        "icon_url" => nil
      )
    end

    it "募集一覧には、その企業の掲載中の募集だけを、最初に掲載した日時の新しい順に並べる" do
      older = create(:job_posting, :published, company_profile: company, published_at: 2.days.ago)
      newer = create(:job_posting, :published, company_profile: company, published_at: 1.day.ago)
      create(:job_posting, company_profile: company)
      create(:job_posting, :closed, company_profile: company)
      create(:job_posting, :published)

      get "/api/student/companies/#{company.id}"

      job_postings = response.parsed_body["job_postings"]
      expect(job_postings.map { |item| item["id"] }).to eq([ newer.id, older.id ])
      # 行は学生向けの募集の行（形B）。matched は検索の窓口だけなので付かない
      expect(job_postings.first).to include("is_open" => true, "company" => include("id" => company.id))
      expect(job_postings.first).not_to have_key("matched")
    end

    it "存在しない番号なら 404" do
      get "/api/student/companies/0"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["message"]).to eq("見つかりません")
    end
  end
end
