require "rails_helper"

# ⑪ 自社の募集の一覧、⑫ 1件、⑬ 新規作成、⑭ 保存のテスト。
# 必須テスト「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3 ⑪〜⑭、その他決め事.md の 5-9、権限_バリデーション.md の 17-2-2・17-3-3・17-3-4
RSpec.describe "企業の募集（/api/company/job_postings）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:company) { company_user.company_profile }
  let(:other_company) { create(:company_user).company_profile }
  let!(:middle_a) { create(:job_middle_category) }
  let!(:middle_b) { create(:job_middle_category) }
  let!(:middle_c) { create(:job_middle_category) }
  let!(:technology_a) { create(:technology) }
  let!(:technology_b) { create(:technology) }
  let!(:prefecture) { create(:prefecture) }

  # 掲載中で作るときの、ひととおりそろった入力
  let(:published_params) do
    {
      status: "published",
      title: "バックエンド開発インターン",
      internship_details: "API を作ります",
      hourly_wage: 1500,
      min_work_days_per_week: 2,
      start_month: "2026-10-01",
      work_style: "partial_remote",
      prefecture_id: prefecture.id,
      main_job_middle_category_ids: [ middle_a.id ],
      related_job_middle_category_ids: [ middle_b.id ],
      technology_ids: [ technology_a.id ]
    }
  end

  # 新規作成・保存を送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def post_job_posting(params)
    post "/api/company/job_postings", params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  def patch_job_posting(job_posting, params)
    patch "/api/company/job_postings/#{job_posting.id}",
          params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      get "/api/company/job_postings"

      expect(response).to have_http_status(:unauthorized)
    end

    it "学生なら、一覧も新規作成も 403" do
      log_in_as(create(:student_user))

      get "/api/company/job_postings"
      expect(response).to have_http_status(:forbidden)

      post_job_posting(status: "unpublished", title: "募集")
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "⑪ 一覧" do
    it "自社の募集だけを、最終更新の新しい順に返す（他社の募集は出ない）" do
      older = create(:job_posting, company_profile: company, updated_at: 2.days.ago)
      newer = create(:job_posting, company_profile: company, updated_at: 1.day.ago)
      create(:job_posting, company_profile: other_company)
      log_in_as(company_user)

      get "/api/company/job_postings"

      expect(response).to have_http_status(:ok)
      items = response.parsed_body["items"]
      expect(items.map { |item| item["id"] }).to eq([ newer.id, older.id ])
      expect(items.first.keys).to contain_exactly("id", "title", "status", "published_at", "updated_at")
    end
  end

  describe "⑫ 1件" do
    before { log_in_as(company_user) }

    it "決めた形で返す。職種は主と関連で配列を分け、空欄は null" do
      job_posting = create(:job_posting, company_profile: company)
      job_posting.job_posting_job_categories.create!(job_middle_category: middle_a, role: :main)
      job_posting.job_posting_job_categories.create!(job_middle_category: middle_b, role: :related)
      job_posting.technologies << technology_a

      get "/api/company/job_postings/#{job_posting.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly(
        "id", "status", "published_at",
        "title", "about", "business_description", "internship_details", "growth",
        "min_work_days_per_week", "min_work_hours_per_day", "min_duration_months", "start_month",
        "work_style", "work_style_note", "prefecture_id", "work_location_note", "weekend_ok", "work_note",
        "hourly_wage", "requirements", "preferred_requirements", "technology_note",
        "culture_pace", "culture_novelty", "culture_collaboration", "culture_decision", "culture_atmosphere",
        "main_job_middle_category_ids", "related_job_middle_category_ids",
        "main_work_process_ids", "involved_work_process_ids",
        "technology_ids", "industry_ids", "business_type_ids",
        "updated_at"
      )
      expect(body["status"]).to eq("unpublished")
      expect(body["main_job_middle_category_ids"]).to eq([ middle_a.id ])
      expect(body["related_job_middle_category_ids"]).to eq([ middle_b.id ])
      expect(body["technology_ids"]).to eq([ technology_a.id ])
      expect(body["about"]).to be_nil
    end

    it "他社の募集の番号なら 404（見てよい範囲の外。必須テスト）" do
      others = create(:job_posting, company_profile: other_company)

      get "/api/company/job_postings/#{others.id}"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["message"]).to eq("見つかりません")
    end

    it "存在しない番号なら 404" do
      get "/api/company/job_postings/0"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "⑬ 新規作成" do
    before { log_in_as(company_user) }

    it "非公開なら、タイトルだけで保存できる（下書き）。最初に掲載した日時は空のまま" do
      expect { post_job_posting(status: "unpublished", title: "下書きの募集") }.to change(JobPosting, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["title"]).to eq("下書きの募集")
      expect(body["published_at"]).to be_nil
      expect(body["internship_details"]).to be_nil
    end

    it "掲載中で作ると、最初に掲載した日時が入り、職種・技術・勤務地も保存される" do
      post_job_posting(published_params)

      expect(response).to have_http_status(:created)
      job_posting = JobPosting.last
      expect(job_posting.company_profile).to eq(company)
      expect(job_posting.published_at).to be_present
      expect(job_posting.main_job_middle_category_ids).to eq([ middle_a.id ])
      expect(job_posting.related_job_middle_category_ids).to eq([ middle_b.id ])
      expect(job_posting.technology_ids).to eq([ technology_a.id ])
      expect(job_posting.prefecture).to eq(prefecture)
      expect(response.parsed_body["start_month"]).to eq("2026-10-01")
    end

    # 順9 で足した項目
    it "カルチャー・工程・業界・事業形態も保存でき、返事にも入る" do
      main_process = create(:work_process)
      involved_process = create(:work_process)
      industry = create(:industry)
      business_type = create(:business_type)

      post_job_posting(published_params.merge(
        culture_pace: -2, culture_novelty: -1, culture_collaboration: 0, culture_decision: 1, culture_atmosphere: 2,
        main_work_process_ids: [ main_process.id ],
        involved_work_process_ids: [ involved_process.id ],
        industry_ids: [ industry.id ],
        business_type_ids: [ business_type.id ]
      ))

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body.values_at(
        "culture_pace", "culture_novelty", "culture_collaboration", "culture_decision", "culture_atmosphere"
      )).to eq([ -2, -1, 0, 1, 2 ])
      expect(body["main_work_process_ids"]).to eq([ main_process.id ])
      expect(body["involved_work_process_ids"]).to eq([ involved_process.id ])
      expect(body["industry_ids"]).to eq([ industry.id ])
      expect(body["business_type_ids"]).to eq([ business_type.id ])
      job_posting = JobPosting.last
      expect(job_posting.main_work_process_ids).to eq([ main_process.id ])
      expect(job_posting.industry_ids).to eq([ industry.id ])
    end

    it "掲載中なのに、インターンですること・時給が空なら 422（掲載に必要）" do
      post_job_posting(status: "published", title: "募集")

      expect(response).to have_http_status(:unprocessable_content)
      errors = response.parsed_body["errors"]
      expect(errors["internship_details"]).to eq([ "インターンですることを入力してください" ])
      expect(errors["hourly_wage"]).to eq([ "時給を入力してください" ])
      expect(JobPosting.count).to eq(0)
    end

    it "「終了」では新規作成できない（422。17-2-2）" do
      post_job_posting(status: "closed", title: "募集")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["status"]).to eq([ "募集状態は一覧にありません" ])
    end

    it "会社や最初に掲載した日時を送っても、使われない" do
      post_job_posting(status: "unpublished", title: "募集",
                       company_profile_id: other_company.id, published_at: "2020-01-01T00:00:00+09:00")

      expect(response).to have_http_status(:created)
      job_posting = JobPosting.last
      expect(job_posting.company_profile).to eq(company)
      expect(job_posting.published_at).to be_nil
    end

    it "タイトルが空なら 422" do
      post_job_posting(status: "unpublished", title: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["title"]).to eq([ "募集タイトルを入力してください" ])
    end
  end

  describe "⑭ 保存" do
    before { log_in_as(company_user) }

    let(:job_posting) { create(:job_posting, company_profile: company) }

    it "他社の募集の番号なら 404。他社の募集は変わらない（見てよい範囲の外。必須テスト）" do
      others = create(:job_posting, company_profile: other_company, title: "他社の募集")

      patch_job_posting(others, title: "書き換え")

      expect(response).to have_http_status(:not_found)
      expect(others.reload.title).to eq("他社の募集")
    end

    it "掲載 → 非公開 → 再掲載しても、最初に掲載した日時は変わらない（17-2-2）" do
      patch_job_posting(job_posting, status: "published")
      first_published_at = job_posting.reload.published_at
      expect(first_published_at).to be_present

      patch_job_posting(job_posting, status: "unpublished")
      patch_job_posting(job_posting, status: "published")

      expect(response).to have_http_status(:ok)
      expect(job_posting.reload.published_at).to eq(first_published_at)
    end

    it "職種と技術は、送った内容に置き換わる（主だった中分類を関連に移せる）" do
      job_posting.job_posting_job_categories.create!(job_middle_category: middle_a, role: :main)
      job_posting.technologies << technology_a

      patch_job_posting(job_posting,
                        main_job_middle_category_ids: [ middle_b.id ],
                        related_job_middle_category_ids: [ middle_a.id ],
                        technology_ids: [ technology_b.id ])

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["main_job_middle_category_ids"]).to eq([ middle_b.id ])
      expect(body["related_job_middle_category_ids"]).to eq([ middle_a.id ])
      expect(body["technology_ids"]).to eq([ technology_b.id ])
      job_posting.reload
      expect(job_posting.main_job_middle_category_ids).to eq([ middle_b.id ])
      expect(job_posting.related_job_middle_category_ids).to eq([ middle_a.id ])
      expect(job_posting.technology_ids).to eq([ technology_b.id ])
    end

    it "技術だけを直しても、最終更新日が今になる（企業が最後に保存した日時。16-3 ⑭）" do
      job_posting.update_column(:updated_at, 1.day.ago)

      patch_job_posting(job_posting, technology_ids: [ technology_a.id ])

      expect(response).to have_http_status(:ok)
      expect(job_posting.reload.updated_at).to be > 1.hour.ago
    end

    it "掲載中のまま、インターンですることを空にすると 422。中身は変わらない" do
      published = create(:job_posting, :published, company_profile: company)

      patch_job_posting(published, internship_details: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["internship_details"]).to eq([ "インターンですることを入力してください" ])
      expect(published.reload.internship_details).to eq("Rails で API を作ります")
    end

    it "終了なら、インターンですることを空にしても保存できる" do
      closed = create(:job_posting, :published, company_profile: company)
      closed.update!(status: :closed)

      patch_job_posting(closed, internship_details: "")

      expect(response).to have_http_status(:ok)
      expect(closed.reload.internship_details).to be_nil
    end
  end

  describe "入力の誤り（422。17-3-4）" do
    before { log_in_as(company_user) }

    let(:job_posting) { create(:job_posting, company_profile: company) }

    it "主と関連に同じ中分類があれば 422。職種は変わらない（先に確かめてから、トランザクションで書き込むため）" do
      job_posting.job_posting_job_categories.create!(job_middle_category: middle_c, role: :main)

      patch_job_posting(job_posting,
                        main_job_middle_category_ids: [ middle_a.id ],
                        related_job_middle_category_ids: [ middle_a.id, middle_b.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["related_job_middle_category_ids"])
        .to eq([ "関連する職種に、主な職種と同じものが含まれています" ])
      expect(job_posting.reload.main_job_middle_category_ids).to eq([ middle_c.id ])
    end

    # 画面では1つの工程にメインか関われるの片方しか付けられないので、画面を通さずに呼ばれたときの備え（PR242）
    it "メインと関われるに同じ工程があれば 422。工程は変わらない" do
      process = create(:work_process)

      patch_job_posting(job_posting, main_work_process_ids: [ process.id ], involved_work_process_ids: [ process.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["involved_work_process_ids"])
        .to eq([ "関われる工程に、メインで担当する工程と同じものが含まれています" ])
      expect(job_posting.reload.job_posting_work_processes).to be_empty
    end

    it "マスタにない技術の番号なら、404 ではなく 422" do
      patch_job_posting(job_posting, technology_ids: [ 0 ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["technology_ids"]).to eq([ "使用技術に選べない値が含まれています" ])
    end

    it "時給が 0 や 100,001 なら 422（1〜100,000円）" do
      [ 0, 100_001 ].each do |wage|
        patch_job_posting(job_posting, hourly_wage: wage)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to have_key("hourly_wage")
      end
    end

    it "週の稼働日数が選択肢にない値なら 422" do
      patch_job_posting(job_posting, min_work_days_per_week: 7)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("min_work_days_per_week")
    end

    it "開始時期が月の1日でなければ 422" do
      patch_job_posting(job_posting, start_month: "2026-10-15")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("start_month")
    end

    it "マスタにない都道府県なら 422" do
      patch_job_posting(job_posting, prefecture_id: 0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["prefecture_id"]).to eq([ "勤務地は一覧にありません" ])
    end
  end
end
