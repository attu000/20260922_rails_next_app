require "rails_helper"

# ㉟ GET /api/student/scouts（スカウト管理）のテスト。
# 詳しくは design/designs/API設計.md の 16-3-6、データベース.md の 8-7
RSpec.describe "スカウト管理（/api/student/scouts）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:student) { student_user.student_profile }

  # 自分のやりとりを、発生元・状態・始まった日時を指定して作る
  def create_own_candidacy(origin, status, created_at: Time.current, job_posting: create(:job_posting, :published))
    create(:candidacy, origin: origin, status: status, created_at: created_at,
                       job_posting: job_posting, student_profile: student)
  end

  it "未ログインなら 401" do
    get "/api/student/scouts"

    expect(response).to have_http_status(:unauthorized)
  end

  it "企業なら 403" do
    log_in_as(create(:company_user))

    get "/api/student/scouts"

    expect(response).to have_http_status(:forbidden)
  end

  context "ログインしている学生" do
    before { log_in_as(student_user) }

    it "スカウトの未マッチと見送りを、どちらも「スカウトあり」として出す（見送りは学生に見せない）" do
      unmatched = create_own_candidacy(:scout, :unmatched)
      declined = create_own_candidacy(:scout, :declined)

      get "/api/student/scouts"

      expect(response).to have_http_status(:ok)
      statuses = response.parsed_body["items"].to_h { |item| [ item["candidacy_id"], item["my_status"] ] }
      expect(statuses).to eq(unmatched.id => "scouted", declined.id => "scouted")
    end

    it "応募したもの、マッチ以降のスカウト（募集管理に出すもの）、ほかの学生のスカウトは出さない" do
      create_own_candidacy(:application, :unmatched)
      create_own_candidacy(:application, :declined)
      create_own_candidacy(:scout, :matched)
      create_own_candidacy(:scout, :passed)
      create(:candidacy, :scout)

      get "/api/student/scouts"

      expect(response.parsed_body["items"]).to eq([])
    end

    it "スカウトが届いた日の新しい順に並べる" do
      old = create_own_candidacy(:scout, :unmatched, created_at: 3.days.ago)
      newest = create_own_candidacy(:scout, :unmatched, created_at: 1.day.ago)
      middle = create_own_candidacy(:scout, :declined, created_at: 2.days.ago)

      get "/api/student/scouts"

      expect(response.parsed_body["items"].map { |item| item["candidacy_id"] }).to eq([ newest.id, middle.id, old.id ])
    end

    it "行は募集管理と同じ形（形B にやりとりの番号と自分の状態）。終了した募集は is_open が false" do
      posting = create(:job_posting, :published)
      candidacy = create_own_candidacy(:scout, :unmatched, job_posting: posting)
      posting.update!(status: :closed)

      get "/api/student/scouts"

      item = response.parsed_body["items"].sole
      expect(item.keys).to contain_exactly(
        "id", "title", "is_open", "company",
        "industry_ids", "business_type_ids",
        "main_job_middle_category_ids", "related_job_middle_category_ids",
        "main_work_process_ids", "involved_work_process_ids",
        "prefecture_id", "work_style", "hourly_wage",
        "min_work_days_per_week", "min_work_hours_per_day", "min_duration_months",
        "published_at", "candidacy_id", "my_status"
      )
      expect(item).to include("id" => posting.id, "is_open" => false, "candidacy_id" => candidacy.id, "my_status" => "scouted")
    end

    it "20件ずつのページに分け、ページの情報を返す" do
      Array.new(21) { |i| create_own_candidacy(:scout, :unmatched, created_at: i.hours.ago) }

      get "/api/student/scouts", params: { page: 2 }

      expect(response.parsed_body["items"].size).to eq(1)
      expect(response.parsed_body["pagination"]).to eq(
        "page" => 2, "per_page" => 20, "total_count" => 21, "total_pages" => 2
      )
    end
  end
end
