require "rails_helper"

# ㉝ この募集に似た募集（/api/student/job_postings/:job_posting_id/similar_job_postings）のテスト。
# 選び方の中身は app/services/similar_job_postings.rb のテストで確かめたので、ここでは
# 「部品が選んだ順のまま返すか」と「番号の確かめ（404）」に絞る。
# 詳しくは design/designs/API設計.md の 16-3 ㉝
RSpec.describe "学生の似た募集（/api/student/job_postings/:job_posting_id/similar_job_postings）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:student) { student_user.student_profile }
  let(:job_posting) { create(:job_posting, :published) }

  def path(job_posting_id = job_posting.id)
    "/api/student/job_postings/#{job_posting_id}/similar_job_postings"
  end

  it "企業なら 403" do
    log_in_as(create(:company_user))

    get path

    expect(response).to have_http_status(:forbidden)
  end

  describe "㉝ 似た募集" do
    before { log_in_as(student_user) }

    it "部品が選んだ順のまま、形B の行を items で包んで返す" do
      first, second = create_list(:job_posting, 2, :published)
      # 番号の小さい順とは逆にして、選んだ順のまま返すことを確かめる
      expect(SimilarJobPostings).to receive(:ids).with(job_posting, student).and_return([ second.id, first.id ])

      get path

      expect(response).to have_http_status(:ok)
      items = response.parsed_body["items"]
      expect(items.map { |item| item["id"] }).to eq([ second.id, first.id ])
      # 行は学生向けの募集の行（形B）。matched は検索の窓口だけなので付かない
      expect(items.first).to include("is_open" => true, "company" => include("id" => second.company_profile_id))
      expect(items.first).not_to have_key("matched")
    end

    it "自分とやりとりがある募集なら、終了していても開ける" do
      closed = create(:job_posting, :closed)
      create(:candidacy, job_posting: closed, student_profile: student)

      get path(closed.id)

      expect(response).to have_http_status(:ok)
    end

    it "やりとりのない非公開・終了の募集なら 404（見てよい範囲の外）" do
      [ create(:job_posting), create(:job_posting, :closed) ].each do |posting|
        get path(posting.id)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
