require "rails_helper"

# ㉓ GET /api/company/students/:id（学生詳細）と ㉒ GET /api/company/students（学生検索）のテスト。
# 必須テスト「学生が企業の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1）を含む。
# 企業はすべての学生を見られるので、学生の「見てよい範囲の外」は存在しない番号だけ（API設計.md の 16-1-10）。
# 学生検索の条件ごとの合う・合わないは spec/services/student_search_spec.rb で確かめる。
# 詳しくは design/designs/API設計.md の 16-3-6（㉒・㉓・形C・形D）
RSpec.describe "企業の学生詳細・学生検索（/api/company/students）", type: :request do
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
      expect(body.keys).to contain_exactly("student", "has_message_thread", "job_postings")
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

    # 順6：この学生とのスレッドがあるか（16-3 ㉓、権限_バリデーション.md の 17-2-3。PR208）
    describe "この学生とのスレッドがあるか（has_message_thread）" do
      it "スレッドがなければ false" do
        get "/api/company/students/#{student.id}"

        expect(response.parsed_body["has_message_thread"]).to be(false)
      end

      it "この学生とのスレッドがあれば true（スカウトを送っただけでも、スレッドはある）" do
        MessageThread.create!(company_profile: company, student_profile: student)

        get "/api/company/students/#{student.id}"

        expect(response.parsed_body["has_message_thread"]).to be(true)
      end

      it "ほかの学生とのスレッドや、他社とこの学生のスレッドしかなければ false" do
        MessageThread.create!(company_profile: company, student_profile: create(:student_user).student_profile)
        MessageThread.create!(company_profile: create(:company_user).company_profile, student_profile: student)

        get "/api/company/students/#{student.id}"

        expect(response.parsed_body["has_message_thread"]).to be(false)
      end
    end
  end

  describe "㉒ 学生検索" do
    it "未ログインなら 401" do
      get "/api/company/students"

      expect(response).to have_http_status(:unauthorized)
    end

    it "学生なら 403" do
      log_in_as(create(:student_user))

      get "/api/company/students"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "企業向けの学生の行（形C）に matched を足した形と、条件に合う件数付きのページの情報を返す" do
        technology = create(:technology)
        middle = create(:job_middle_category)
        student.update!(grade: :undergrad_3, graduation_year: 2028, activity_status: :job_hunting,
                        work_days_per_week: 3, work_hours_per_day: 4, duration_months: 6,
                        interested_job_middle_category_ids: [ middle.id ])
        StudentSkill.create!(student_profile: student, technology: technology, level: :v2)
        # 条件（学年）に合わない学生
        create(:student_user).student_profile.update!(grade: :master_1)

        get "/api/company/students", params: { grades: [ "undergrad_3" ] }

        expect(response).to have_http_status(:ok)
        first, second = response.parsed_body["items"]
        expect(first.keys).to contain_exactly(
          "id", "name", "icon_url", "grade", "graduation_year", "activity_status",
          "interested_job_middle_category_ids", "skills",
          "work_days_per_week", "work_hours_per_day", "duration_months", "matched",
          "candidacy", "candidacy_count"
        )
        expect(first).to include(
          "id" => student.id, "name" => student.name, "icon_url" => nil,
          "grade" => "undergrad_3", "graduation_year" => 2028, "activity_status" => "job_hunting",
          "interested_job_middle_category_ids" => [ middle.id ],
          "skills" => [ { "technology_id" => technology.id, "other_name" => nil, "level" => "v2" } ],
          "work_days_per_week" => 3, "work_hours_per_day" => 4, "duration_months" => 6,
          "matched" => true
        )
        # 条件に合わない学生も、減らさずに後ろに出す
        expect(second["matched"]).to be(false)
        expect(response.parsed_body["pagination"]).to eq(
          "page" => 1, "per_page" => 20, "total_count" => 2, "matched_count" => 1, "total_pages" => 1
        )
      end

      it "30日より前に活動した学生は出さない" do
        student
        create(:student_user, last_active_on: Time.zone.today - 31)

        get "/api/company/students"

        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ student.id ])
      end

      # 必須テスト：他社の募集の番号を job_posting_id に入れても使えない（16-1-10）
      it "他社の募集の番号を job_posting_id に入れると 404" do
        get "/api/company/students", params: { job_posting_id: create(:job_posting, :published).id }

        expect(response).to have_http_status(:not_found)
      end

      it "おすすめ順なのに job_posting_id がなければ 422" do
        get "/api/company/students", params: { sort: "recommended" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"].keys).to eq([ "job_posting_id" ])
      end

      it "自社の募集を選べば、おすすめ順で並べられる（今は仮の全員0点なので、最終活動の新しい順。PR214）" do
        job_posting = create(:job_posting, company_profile: company)
        older = create(:student_user, last_active_on: Time.zone.today - 3).student_profile
        newer = create(:student_user, last_active_on: Time.zone.today - 1).student_profile

        get "/api/company/students", params: { job_posting_id: job_posting.id, sort: "recommended" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ newer.id, older.id ])
      end

      # 行のタグ（PR219）。スカウト済み・見送り・マッチ以降の学生は検索の本体が除く（PR220）ので、残るのは未対応応募だけ
      describe "行のタグ用の candidacy と candidacy_count" do
        let(:posting) { create(:job_posting, :published, company_profile: company) }

        it "募集を選ぶと、その募集の未対応応募の学生に candidacy（tag は pending_application）を返す。やりとりのない学生は null" do
          candidacy = create(:candidacy, job_posting: posting, student_profile: student)
          no_candidacy = create(:student_user).student_profile

          get "/api/company/students", params: { job_posting_id: posting.id }

          items = response.parsed_body["items"].index_by { |item| item["id"] }
          expect(items[student.id]["candidacy"]).to eq(
            "id" => candidacy.id, "origin" => "application", "status" => "unmatched", "tag" => "pending_application"
          )
          expect(items[no_candidacy.id]["candidacy"]).to be_nil
        end

        it "募集を選ばないと、candidacy は常に null。candidacy_count は自社の募集とのやりとりの件数（他社の分は数えない）" do
          create(:candidacy, job_posting: posting, student_profile: student)
          create(:candidacy, :scout, job_posting: create(:job_posting, :published), student_profile: student)

          get "/api/company/students"

          item = response.parsed_body["items"].sole
          expect(item).to include("candidacy" => nil, "candidacy_count" => 1)
        end

        it "スカウト済みの学生は、その募集を選ぶと出てこない（PR220）" do
          create(:candidacy, :scout, job_posting: posting, student_profile: student)

          get "/api/company/students", params: { job_posting_id: posting.id }

          expect(response.parsed_body["items"]).to eq([])
        end
      end

      it "20件ずつのページに分ける" do
        Array.new(21) { create(:student_user) }

        get "/api/company/students", params: { page: 2 }

        expect(response.parsed_body["items"].size).to eq(1)
        expect(response.parsed_body["pagination"]).to include("total_count" => 21, "matched_count" => 21, "total_pages" => 2)
      end
    end
  end
end
