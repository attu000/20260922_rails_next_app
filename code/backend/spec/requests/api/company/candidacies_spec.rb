require "rails_helper"

# ㉑ GET /api/company/candidacies（候補者一覧）のテスト。
# 必須テスト「学生が企業の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-6、データベース.md の 8-7
RSpec.describe "企業のやりとり（/api/company/candidacies）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:company) { company_user.company_profile }
  let(:posting) { create(:job_posting, :published, company_profile: company) }

  describe "㉑ 候補者一覧" do
    it "未ログインなら 401" do
      get "/api/company/candidacies"

      expect(response).to have_http_status(:unauthorized)
    end

    it "学生なら 403" do
      log_in_as(create(:student_user))

      get "/api/company/candidacies"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "自社の募集へのやりとりだけを返す。他社の募集へのやりとりは出さない" do
        own = create(:candidacy, job_posting: posting)
        create(:candidacy)

        get "/api/company/candidacies"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ own.id ])
      end

      it "行の形。学生の情報と、Rails が計算したタグを返す" do
        student = create(:student_user).student_profile
        student.update!(grade: :undergrad_3, graduation_year: 2028, activity_status: :job_hunting)
        candidacy = create(:candidacy, job_posting: posting, student_profile: student)

        get "/api/company/candidacies"

        item = response.parsed_body["items"].sole
        expect(item.keys).to contain_exactly(
          "id", "job_posting", "student", "origin", "status", "tag", "created_at", "matched_at"
        )
        expect(item).to include(
          "id" => candidacy.id,
          "job_posting" => { "id" => posting.id, "title" => posting.title, "status" => "published" },
          "student" => {
            "id" => student.id, "name" => student.name, "icon_url" => nil,
            "grade" => "undergrad_3", "graduation_year" => 2028, "activity_status" => "job_hunting"
          },
          "origin" => "application",
          "status" => "unmatched",
          "tag" => "pending_application",
          "matched_at" => nil
        )
      end

      it "タグは、応募の未マッチが未対応応募、スカウトの未マッチがスカウト済み、マッチはマッチ" do
        tags = {
          create(:candidacy, job_posting: posting) => "pending_application",
          create(:candidacy, :scout, job_posting: posting) => "scouted",
          create(:candidacy, :scout, job_posting: posting, status: :matched) => "matched"
        }

        get "/api/company/candidacies"

        expect(response.parsed_body["items"].to_h { |item| [ item["id"], item["tag"] ] }).to eq(tags.transform_keys(&:id))
      end

      it "job_posting_id を送ると、その募集のやりとりだけを返す（募集別のタブ）" do
        other_posting = create(:job_posting, :published, company_profile: company)
        target = create(:candidacy, job_posting: posting)
        create(:candidacy, job_posting: other_posting)

        get "/api/company/candidacies", params: { job_posting_id: posting.id }

        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ target.id ])
      end

      # 必須テスト：他社の募集の番号を job_posting_id に入れても見られない（16-1-10）
      it "他社の募集の番号を job_posting_id に入れると 404" do
        other_company_posting = create(:job_posting, :published)
        create(:candidacy, job_posting: other_company_posting)

        get "/api/company/candidacies", params: { job_posting_id: other_company_posting.id }

        expect(response).to have_http_status(:not_found)
      end

      it "存在しない募集の番号なら 404" do
        get "/api/company/candidacies", params: { job_posting_id: 0 }

        expect(response).to have_http_status(:not_found)
      end

      it "やりとりが始まった日の新しい順に並べる" do
        old = create(:candidacy, job_posting: posting, created_at: 3.days.ago)
        newest = create(:candidacy, job_posting: posting, created_at: 1.day.ago)
        middle = create(:candidacy, job_posting: posting, created_at: 2.days.ago)

        get "/api/company/candidacies"

        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ newest.id, middle.id, old.id ])
      end

      it "20件ずつのページに分け、ページの情報を返す" do
        Array.new(21) { |i| create(:candidacy, job_posting: posting, created_at: i.hours.ago) }

        get "/api/company/candidacies", params: { page: 2 }

        expect(response.parsed_body["items"].size).to eq(1)
        expect(response.parsed_body["pagination"]).to eq(
          "page" => 2, "per_page" => 20, "total_count" => 21, "total_pages" => 2
        )
      end
    end
  end
end
