require "rails_helper"

# ㉓ GET /api/company/students/:id（学生詳細）のテスト。
# 必須テスト「学生が企業の窓口を呼ぶと 403」（技術構成.md の 3-3 D-1）を含む。
# 企業はすべての学生を見られるので、「見てよい範囲の外」は存在しない番号だけ（API設計.md の 16-1-10）。
# 詳しくは design/designs/API設計.md の 16-3-6（㉓・形D）
RSpec.describe "企業の学生詳細（/api/company/students/:id）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:company) { company_user.company_profile }
  let(:student) { create(:student_user).student_profile }

  it "未ログインなら 401" do
    get "/api/company/students/#{student.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  it "学生なら 403" do
    log_in_as(create(:student_user))

    get "/api/company/students/#{student.id}"

    expect(response).to have_http_status(:forbidden)
  end

  context "ログインしている企業" do
    before { log_in_as(company_user) }

    it "学生のプロフィールを、マイページと同じ項目で返す（マッチ前でもすべて見せる）" do
      student.update!(self_pr_strength: "粘り強い", work_days_per_week: 3)

      get "/api/company/students/#{student.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly("student", "job_postings")
      expect(body["student"].keys).to contain_exactly(
        "name", "university_id", "university_other_name", "faculty_id", "department_id", "grade",
        "graduation_year", "prefecture_id", "activity_status",
        "self_pr_strength", "self_pr_weakness", "self_pr_future",
        "work_days_per_week", "work_hours_per_day", "duration_months", "available_from",
        "can_full_remote", "can_partial_remote", "can_onsite", "work_note",
        "interested_job_middle_category_ids", "commutable_prefecture_ids", "skills", "icon_url"
      )
      expect(body["student"]).to include("name" => student.name, "self_pr_strength" => "粘り強い", "work_days_per_week" => 3)
    end

    it "自社の全募集（非公開・終了も含む）を、最終更新の新しい順に返す。他社の募集は入らない" do
      closed = create(:job_posting, :closed, company_profile: company)
      published = create(:job_posting, :published, company_profile: company)
      unpublished = create(:job_posting, company_profile: company)
      create(:job_posting, :published)
      # 終了のひな形は作ったあとに状態を変えるので、最終更新日時は作り終えてから直接入れる
      # （update_columns はモデルの処理を通さず、updated_at も自動で変えない）
      closed.update_columns(updated_at: 3.days.ago)
      published.update_columns(updated_at: 1.day.ago)
      unpublished.update_columns(updated_at: 2.days.ago)

      get "/api/company/students/#{student.id}"

      job_postings = response.parsed_body["job_postings"]
      expect(job_postings.map { |job_posting| job_posting["id"] }).to eq([ published.id, unpublished.id, closed.id ])
      expect(job_postings.map { |job_posting| job_posting["status"] }).to eq(%w[published unpublished closed])
    end

    it "やりとりのない掲載中の募集は、candidacy が null で、「スカウトをする」のボタンを返す" do
      posting = create(:job_posting, :published, company_profile: company)

      get "/api/company/students/#{student.id}"

      expect(response.parsed_body["job_postings"].sole).to eq(
        "id" => posting.id, "title" => posting.title, "status" => "published",
        "candidacy" => nil, "available_actions" => [ "scout" ]
      )
    end

    it "やりとりのない募集でも、掲載中でなければ押せるボタンなし" do
      create(:job_posting, :closed, company_profile: company)

      get "/api/company/students/#{student.id}"

      expect(response.parsed_body["job_postings"].sole["available_actions"]).to eq([])
    end

    it "応募のある掲載中の募集は、やりとりの状態・タグと、「マッチする」のボタンを返す" do
      posting = create(:job_posting, :published, company_profile: company)
      candidacy = create(:candidacy, job_posting: posting, student_profile: student)

      get "/api/company/students/#{student.id}"

      expect(response.parsed_body["job_postings"].sole).to include(
        "candidacy" => {
          "id" => candidacy.id, "origin" => "application", "status" => "unmatched",
          "tag" => "pending_application", "matched_at" => nil
        },
        "available_actions" => [ "match" ]
      )
    end

    it "ほかの学生とのやりとりは、この学生の状態として出さない" do
      posting = create(:job_posting, :published, company_profile: company)
      create(:candidacy, job_posting: posting)

      get "/api/company/students/#{student.id}"

      expect(response.parsed_body["job_postings"].sole["candidacy"]).to be_nil
    end

    it "存在しない学生の番号なら 404" do
      get "/api/company/students/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
