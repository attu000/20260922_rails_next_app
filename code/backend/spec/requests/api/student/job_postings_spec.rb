require "rails_helper"

# ⑱ 募集検索、⑲ 募集詳細、種別の入口の確認のテスト。
# 必須テスト「企業が学生の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 検索の条件ごとの合う・合わないは spec/services/job_posting_search_spec.rb で確かめる。
# 詳しくは design/designs/API設計.md の 16-1-11、16-3 ⑱⑲
RSpec.describe "学生の募集検索・募集詳細（/api/student/job_postings）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:company) { create(:company_user).company_profile }

  def create_posting(**attributes)
    create(:job_posting, :published, company_profile: company, **attributes)
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      get "/api/student/job_postings"

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら、募集検索も募集詳細も 403" do
      posting = create_posting
      log_in_as(create(:company_user))

      get "/api/student/job_postings"
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["message"]).to eq("この操作はできません")

      get "/api/student/job_postings/#{posting.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "⑱ 募集検索" do
    before { log_in_as(student_user) }

    it "学生向けの募集の行に matched を足した形と、ページの情報を返す" do
      middle = create(:job_middle_category)
      prefecture = create(:prefecture)
      posting = create_posting(work_style: :partial_remote, prefecture: prefecture, min_work_days_per_week: 2)
      posting.job_posting_job_categories.create!(job_middle_category: middle, role: :main)

      get "/api/student/job_postings"

      expect(response).to have_http_status(:ok)
      item = response.parsed_body["items"].first
      expect(item.keys).to contain_exactly(
        "id", "title", "is_open", "company",
        "main_job_middle_category_ids", "related_job_middle_category_ids",
        "prefecture_id", "work_style", "hourly_wage",
        "min_work_days_per_week", "min_work_hours_per_day", "min_duration_months",
        "published_at", "matched"
      )
      expect(item).to include(
        "id" => posting.id,
        "is_open" => true,
        "company" => { "id" => company.id, "name" => company.name, "icon_url" => nil },
        "main_job_middle_category_ids" => [ middle.id ],
        "related_job_middle_category_ids" => [],
        "prefecture_id" => prefecture.id,
        "work_style" => "partial_remote",
        "min_work_days_per_week" => 2,
        "matched" => true
      )
      expect(response.parsed_body["pagination"]).to eq(
        "page" => 1, "per_page" => 20, "total_count" => 1, "matched_count" => 1, "total_pages" => 1
      )
    end

    # 新着順は SQL で並べたものを、おすすめ順は Ruby の配列を、ページに分ける（技術構成.md の 9-1-1 の2）。
    # どちらの通り道でも、2つの群を通してページを数える
    %w[newest recommended].each do |sort|
      it "ページは2つの群を通して数え、2ページ目の途中で合致外に変わる（#{sort}）" do
        # 合致21件（10〜30時間前）と、それより新しい合致外4件（0〜3時間前）
        matched = Array.new(21) { |i| create_posting(title: "Ruby #{i}", published_at: (i + 10).hours.ago) }
        unmatched = Array.new(4) { |i| create_posting(title: "Go #{i}", published_at: i.hours.ago) }

        get "/api/student/job_postings", params: { q: "ruby", sort: sort }

        first_page = response.parsed_body
        expect(first_page["items"].map { |item| item["id"] }).to eq(matched.first(20).map(&:id))
        expect(first_page["items"].map { |item| item["matched"] }).to all(be(true))
        expect(first_page["pagination"]).to eq(
          "page" => 1, "per_page" => 20, "total_count" => 25, "matched_count" => 21, "total_pages" => 2
        )

        get "/api/student/job_postings", params: { q: "ruby", sort: sort, page: 2 }

        second_page = response.parsed_body
        expect(second_page["items"].map { |item| item["id"] }).to eq([ matched.last.id ] + unmatched.map(&:id))
        expect(second_page["items"].map { |item| item["matched"] }).to eq([ true, false, false, false, false ])
        expect(second_page["pagination"]["page"]).to eq(2)
      end
    end

    it "ページ番号が数でなければ、1ページ目を返す" do
      create_posting

      get "/api/student/job_postings", params: { page: "abc" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["pagination"]["page"]).to eq(1)
      expect(response.parsed_body["items"].size).to eq(1)
    end

    it "範囲外のページなら、空の一覧を返す" do
      create_posting

      get "/api/student/job_postings", params: { page: 10 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["items"]).to eq([])
      expect(response.parsed_body["pagination"]["total_count"]).to eq(1)
    end
  end

  describe "⑲ 募集詳細" do
    before { log_in_as(student_user) }

    it "掲載中の募集を、決めた形で返す。学生に見せない項目は含めない" do
      technology = create(:technology)
      posting = create_posting(business_description: "募集に書いた事業内容", start_month: Date.new(2026, 11, 1))
      posting.technologies << technology

      get "/api/student/job_postings/#{posting.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly(
        "id", "title", "is_open", "company", "about", "business_description",
        "internship_details", "growth",
        "min_work_days_per_week", "min_work_hours_per_day", "min_duration_months", "start_month",
        "work_style", "work_style_note", "prefecture_id", "work_location_note", "weekend_ok", "work_note",
        "hourly_wage", "requirements", "preferred_requirements", "technology_note",
        "main_job_middle_category_ids", "related_job_middle_category_ids", "technology_ids",
        "published_at"
      )
      expect(body).to include(
        "id" => posting.id,
        "is_open" => true,
        "company" => { "id" => company.id, "name" => company.name, "icon_url" => nil },
        "business_description" => "募集に書いた事業内容",
        "start_month" => "2026-11-01",
        "technology_ids" => [ technology.id ]
      )
    end

    it "どんな会社か・事業内容が募集で空欄なら、企業プロフィールの値を返す" do
      company.update!(about: "会社の紹介", business_description: "会社の事業内容")
      posting = create_posting(about: nil, business_description: nil)

      get "/api/student/job_postings/#{posting.id}"

      expect(response.parsed_body).to include("about" => "会社の紹介", "business_description" => "会社の事業内容")
    end

    it "募集にも企業プロフィールにもなければ null" do
      posting = create_posting(about: nil)

      get "/api/student/job_postings/#{posting.id}"

      expect(response.parsed_body["about"]).to be_nil
    end

    # 必須テスト：関係のない学生は、掲載中でない募集を開けない（16-1-10）。
    # 順5 で「自分とやりとりがある募集」は開けるようにし、そのテストを足す
    {
      "一度も掲載していない募集" => [],
      "掲載したあと非公開に戻した募集" => [ :unpublished_after_published ],
      "終了した募集" => [ :closed ]
    }.each do |label, traits|
      it "関係のない学生が、#{label}の番号で開くと 404" do
        posting = create(:job_posting, *traits, company_profile: company)

        get "/api/student/job_postings/#{posting.id}"

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("見つかりません")
      end
    end

    it "存在しない番号なら 404" do
      get "/api/student/job_postings/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
