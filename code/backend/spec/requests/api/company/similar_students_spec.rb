require "rails_helper"

# ㉕ この学生に似た学生（/api/company/students/:student_id/similar_students）のテスト。
# 選び方の中身は app/services/similar_students.rb のテストで確かめたので、ここでは
# 「部品が選んだ順のまま返すか」と「番号の確かめ（404・422）」に絞る。
# 詳しくは design/designs/API設計.md の 16-3 ㉕
RSpec.describe "企業の似た学生（/api/company/students/:student_id/similar_students）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:company) { company_user.company_profile }
  let(:student) { create(:student_user).student_profile }
  let(:job_posting) { create(:job_posting, :published, company_profile: company) }

  def path(student_id = student.id)
    "/api/company/students/#{student_id}/similar_students"
  end

  it "学生なら 403" do
    log_in_as(create(:student_user))

    get path, params: { job_posting_id: job_posting.id }

    expect(response).to have_http_status(:forbidden)
  end

  describe "㉕ 似た学生" do
    before { log_in_as(company_user) }

    it "部品が選んだ順のまま、形C の行を items で包んで返す" do
      first, second = create_list(:student_user, 2).map(&:student_profile)
      # 番号の小さい順とは逆にして、選んだ順のまま返すことを確かめる
      expect(SimilarStudents).to receive(:ids).with(student, job_posting).and_return([ second.id, first.id ])

      get path, params: { job_posting_id: job_posting.id }

      expect(response).to have_http_status(:ok)
      items = response.parsed_body["items"]
      expect(items.map { |item| item["id"] }).to eq([ second.id, first.id ])
      expect(items.first.keys).to contain_exactly(
        "id", "name", "icon_url", "grade", "graduation_year", "activity_status",
        "interested_job_middle_category_ids", "skills", "work_days_per_week", "work_hours_per_day", "duration_months",
        "last_active_range"
      )
    end

    it "似た学生がいなければ、空の items を返す" do
      get path, params: { job_posting_id: job_posting.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("items" => [])
    end

    it "job_posting_id がなければ 422" do
      get path

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "他社の募集の番号なら 404（見てよい範囲の外）" do
      others = create(:job_posting, :published)

      get path, params: { job_posting_id: others.id }

      expect(response).to have_http_status(:not_found)
    end

    it "存在しない学生の番号なら 404" do
      get path(0), params: { job_posting_id: job_posting.id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
