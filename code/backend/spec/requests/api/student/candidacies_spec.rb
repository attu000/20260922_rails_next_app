require "rails_helper"

# ㉛ POST /api/student/candidacies（応募）、㉞ GET /api/student/candidacies（募集管理）、
# ㉜ POST /api/student/candidacies/:id/match（スカウトにマッチ）のテスト。
# 必須テスト「企業が学生の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1・17-3-4・17-3-6、データベース.md の 8-7
RSpec.describe "学生のやりとり（応募・募集管理。/api/student/candidacies）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:student) { student_user.student_profile }
  let(:posting) { create(:job_posting, :published) }

  # 応募を送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def apply(job_posting_id: posting.id, reasons: %w[business culture])
    post "/api/student/candidacies",
         params: { job_posting_id: job_posting_id, reasons: reasons },
         headers: { "X-CSRF-Token" => csrf_token },
         as: :json
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      apply

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら 403" do
      log_in_as(create(:company_user))

      apply

      expect(response).to have_http_status(:forbidden)
      expect(Candidacy.count).to eq(0)
    end
  end

  describe "応募する" do
    before { log_in_as(student_user) }

    it "201 と「応募済み」を返し、やりとり・応募理由・理由の組の写しを作る" do
      apply(reasons: %w[business culture])

      expect(response).to have_http_status(:created)
      candidacy = Candidacy.sole
      expect(response.parsed_body).to eq("my_status" => "applied", "my_candidacy_id" => candidacy.id)
      expect(candidacy).to have_attributes(
        job_posting_id: posting.id, student_profile_id: student.id,
        origin: "application", status: "unmatched", matched_at: nil,
        # 事業内容（0）とカルチャー（5）：1 + 32
        reason_mask: 33
      )
      expect(candidacy.candidacy_reasons.pluck(:reason)).to contain_exactly("business", "culture")
    end

    it "応募したあとの募集詳細では「応募済み」になる" do
      apply

      get "/api/student/job_postings/#{posting.id}"

      expect(response.parsed_body).to include("my_status" => "applied", "my_candidacy_id" => Candidacy.sole.id)
    end
  end

  describe "今の状態ではできない（409）" do
    before { log_in_as(student_user) }

    it "同じ募集に2回目の応募をすると 409。やりとりは増えない" do
      apply

      apply

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("message" => "この操作は今はできません。画面を読み込み直してください")
      expect(Candidacy.count).to eq(1)
    end

    it "応募したあとに終了した募集へ、もう一度応募すると 409（やりとりがあるので募集は見える）" do
      apply
      posting.update!(status: :closed)

      apply

      expect(response).to have_http_status(:conflict)
    end

    it "スカウトが届いている募集に応募すると 409（スカウトには「マッチする」で応える）" do
      create(:candidacy, :scout, job_posting: posting, student_profile: student)

      apply

      expect(response).to have_http_status(:conflict)
      expect(Candidacy.sole).to be_scout
    end
  end

  describe "見てよい範囲の外（404）" do
    before { log_in_as(student_user) }

    # 必須テスト：関係のない学生は、掲載中でない募集を扱えない（16-1-10）
    {
      "一度も掲載していない募集" => [],
      "掲載したあと非公開に戻した募集" => [ :unpublished_after_published ],
      "終了した募集" => [ :closed ]
    }.each do |label, traits|
      it "関係のない学生が、#{label}に応募すると 404" do
        other_posting = create(:job_posting, *traits)

        apply(job_posting_id: other_posting.id)

        expect(response).to have_http_status(:not_found)
        expect(Candidacy.count).to eq(0)
      end
    end

    it "存在しない番号なら 404" do
      apply(job_posting_id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "入力の誤り（422）" do
    before { log_in_as(student_user) }

    {
      "理由が0個" => [ [], "応募理由を入力してください" ],
      "12個にない値がある" => [ %w[business unknown], "応募理由に選べない値が含まれています" ],
      "同じ値が重複している" => [ %w[business business], "応募理由に同じ値が重複しています" ]
    }.each do |label, (reasons, message)|
      it "#{label}なら 422。やりとりは作られない" do
        apply(reasons: reasons)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to eq("reasons" => [ message ])
        expect(Candidacy.count).to eq(0)
        expect(CandidacyReason.count).to eq(0)
      end
    end

    it "理由を送らなければ 422" do
      post "/api/student/candidacies",
           params: { job_posting_id: posting.id },
           headers: { "X-CSRF-Token" => csrf_token },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("reasons" => [ "応募理由を入力してください" ])
    end

    it "募集の番号を送らなければ 422" do
      post "/api/student/candidacies",
           params: { reasons: %w[business] },
           headers: { "X-CSRF-Token" => csrf_token },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].keys).to eq([ "job_posting_id" ])
    end
  end

  describe "㉞ 募集管理" do
    # 自分のやりとりを、発生元・状態・始まった日時を指定して作る
    def create_own_candidacy(origin, status, created_at: Time.current, job_posting: create(:job_posting, :published))
      create(:candidacy, origin: origin, status: status, created_at: created_at,
                         job_posting: job_posting, student_profile: student)
    end

    it "未ログインなら 401" do
      get "/api/student/candidacies"

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら 403" do
      log_in_as(create(:company_user))

      get "/api/student/candidacies"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている学生" do
      before { log_in_as(student_user) }

      it "応募したもの（状態は問わない）と、スカウトからマッチしたものを出す。見送り・合格・不合格は学生に見せない" do
        shown = {
          create_own_candidacy(:application, :unmatched) => "applied",
          create_own_candidacy(:application, :declined) => "applied",
          create_own_candidacy(:application, :matched) => "matched",
          create_own_candidacy(:application, :passed) => "matched",
          create_own_candidacy(:scout, :matched) => "matched",
          create_own_candidacy(:scout, :failed) => "matched"
        }

        get "/api/student/candidacies"

        expect(response).to have_http_status(:ok)
        statuses = response.parsed_body["items"].to_h { |item| [ item["candidacy_id"], item["my_status"] ] }
        expect(statuses).to eq(shown.transform_keys(&:id))
      end

      it "スカウトの未マッチ・見送り（スカウト管理に出すもの）と、ほかの学生のやりとりは出さない" do
        create_own_candidacy(:scout, :unmatched)
        create_own_candidacy(:scout, :declined)
        create(:candidacy)

        get "/api/student/candidacies"

        expect(response.parsed_body["items"]).to eq([])
      end

      it "やりとりが始まった日の新しい順に並べる" do
        old = create_own_candidacy(:application, :unmatched, created_at: 3.days.ago)
        newest = create_own_candidacy(:scout, :matched, created_at: 1.day.ago)
        middle = create_own_candidacy(:application, :matched, created_at: 2.days.ago)

        get "/api/student/candidacies"

        expect(response.parsed_body["items"].map { |item| item["candidacy_id"] }).to eq([ newest.id, middle.id, old.id ])
      end

      it "行は形B にやりとりの番号と自分の状態を足した形。終了した募集は is_open が false" do
        posting = create(:job_posting, :published)
        candidacy = create_own_candidacy(:application, :unmatched, job_posting: posting)
        posting.update!(status: :closed)

        get "/api/student/candidacies"

        item = response.parsed_body["items"].sole
        expect(item.keys).to contain_exactly(
          "id", "title", "is_open", "company",
          "main_job_middle_category_ids", "related_job_middle_category_ids",
          "prefecture_id", "work_style", "hourly_wage",
          "min_work_days_per_week", "min_work_hours_per_day", "min_duration_months",
          "published_at", "candidacy_id", "my_status"
        )
        expect(item).to include("id" => posting.id, "is_open" => false, "candidacy_id" => candidacy.id, "my_status" => "applied")
      end

      it "20件ずつのページに分け、ページの情報を返す（条件に合う件数は返さない）" do
        Array.new(21) { |i| create_own_candidacy(:application, :unmatched, created_at: i.hours.ago) }

        get "/api/student/candidacies", params: { page: 2 }

        expect(response.parsed_body["items"].size).to eq(1)
        expect(response.parsed_body["pagination"]).to eq(
          "page" => 2, "per_page" => 20, "total_count" => 21, "total_pages" => 2
        )
      end
    end
  end

  describe "㉜ スカウトにマッチ" do
    # マッチを送る。テストでも CSRF 対策は有効なので、合言葉を付ける
    def post_match(candidacy_id, reasons: %w[business culture])
      post "/api/student/candidacies/#{candidacy_id}/match",
           params: { reasons: reasons },
           headers: { "X-CSRF-Token" => csrf_token },
           as: :json
    end

    it "企業なら 403" do
      candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student)
      log_in_as(create(:company_user))

      post_match(candidacy.id)

      expect(response).to have_http_status(:forbidden)
      expect(candidacy.reload).to be_unmatched
    end

    context "ログインしている学生" do
      before { log_in_as(student_user) }

      it "200 と「マッチ済み」を返し、マッチした日時・マッチ理由・理由の組の写しを保存する" do
        candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student)

        post_match(candidacy.id, reasons: %w[business culture])

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("my_status" => "matched", "my_candidacy_id" => candidacy.id)
        candidacy.reload
        expect(candidacy).to be_matched
        expect(candidacy.matched_at).to be_present
        # 事業内容（0）とカルチャー（5）：1 + 32
        expect(candidacy.reason_mask).to eq(33)
        expect(candidacy.reasons).to contain_exactly("business", "culture")
      end

      it "企業に見送られたスカウトにもマッチできる（見送りは学生に見せないため）" do
        candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student, status: :declined)

        post_match(candidacy.id)

        expect(response).to have_http_status(:ok)
        expect(candidacy.reload).to be_matched
      end

      it "マッチしたあとは、スカウト管理から消え、募集管理に出る" do
        candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student)

        post_match(candidacy.id)
        get "/api/student/scouts"
        scouts = response.parsed_body["items"]
        get "/api/student/candidacies"

        expect(scouts).to eq([])
        expect(response.parsed_body["items"].sole).to include("candidacy_id" => candidacy.id, "my_status" => "matched")
      end

      # 今の状態ではできない（権限_バリデーション.md の 17-2-1）
      {
        "応募から始まったやりとり（企業が応じたときにマッチする）" => { origin: :application },
        "もうマッチ済みのやりとり" => { origin: :scout, status: :matched }
      }.each do |label, attributes|
        it "#{label}なら 409。状態は変わらず、理由も保存されない" do
          candidacy = create(:candidacy, job_posting: posting, student_profile: student, **attributes)

          post_match(candidacy.id)

          expect(response).to have_http_status(:conflict)
          expect(response.parsed_body["message"]).to eq("この操作は今はできません。画面を読み込み直してください")
          expect(candidacy.reload.status).to eq((attributes[:status] || :unmatched).to_s)
          expect(CandidacyReason.count).to eq(0)
        end
      end

      it "募集が掲載中でなければ 409" do
        candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student)
        posting.update!(status: :closed)

        post_match(candidacy.id)

        expect(response).to have_http_status(:conflict)
        expect(candidacy.reload).to be_unmatched
      end

      # 確かめる順番は「番号（404）→ 状態（409）→ 入力（422）」（16-3-6）
      it "掲載中でない募集で、理由も0個なら、状態の確かめが先で 409" do
        candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student)
        posting.update!(status: :closed)

        post_match(candidacy.id, reasons: [])

        expect(response).to have_http_status(:conflict)
      end

      # 必須テスト：他人のやりとりの番号は 404（16-1-10）
      it "ほかの学生のやりとりの番号なら 404。状態は変わらない" do
        other_candidacy = create(:candidacy, :scout, job_posting: posting)

        post_match(other_candidacy.id)

        expect(response).to have_http_status(:not_found)
        expect(other_candidacy.reload).to be_unmatched
      end

      it "存在しない番号なら 404" do
        post_match(0)

        expect(response).to have_http_status(:not_found)
      end

      # マッチ理由は、応募理由と同じ項目・同じ確かめ（技術構成.md の 9-2）
      {
        "理由が0個" => [ [], "応募理由を入力してください" ],
        "12個にない値がある" => [ %w[business unknown], "応募理由に選べない値が含まれています" ]
      }.each do |label, (reasons, message)|
        it "#{label}なら 422。状態は変わらず、理由も保存されない" do
          candidacy = create(:candidacy, :scout, job_posting: posting, student_profile: student)

          post_match(candidacy.id, reasons: reasons)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["errors"]).to eq("reasons" => [ message ])
          expect(candidacy.reload).to be_unmatched
          expect(candidacy.matched_at).to be_nil
          expect(CandidacyReason.count).to eq(0)
        end
      end
    end
  end
end
