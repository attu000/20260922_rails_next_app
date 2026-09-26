require "rails_helper"

# ㉑ GET /api/company/candidacies（候補者一覧）と ㉖ POST /api/company/candidacies/:id/match（マッチ）のテスト。
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
          "id", "job_posting", "student", "origin", "status", "tag", "after_match", "created_at", "matched_at"
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
          "after_match" => false,
          "matched_at" => nil
        )
      end

      # 「メッセージ」のボタンを出すか（PR224）
      it "after_match は、未マッチ・見送りの行は false、マッチ・合格の行は true" do
        expected = {
          create(:candidacy, job_posting: posting) => false,
          create(:candidacy, job_posting: posting, status: :declined) => false,
          create(:candidacy, :scout, job_posting: posting, status: :matched) => true,
          create(:candidacy, job_posting: posting, status: :passed) => true
        }

        get "/api/company/candidacies"

        expect(response.parsed_body["items"].to_h { |item| [ item["id"], item["after_match"] ] })
          .to eq(expected.transform_keys(&:id))
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

  describe "㉖ マッチ" do
    let(:student) { create(:student_user).student_profile }

    # マッチを送る。テストでも CSRF 対策は有効なので、合言葉を付ける
    def post_match(candidacy_id)
      post "/api/company/candidacies/#{candidacy_id}/match", headers: { "X-CSRF-Token" => csrf_token }, as: :json
    end

    it "学生なら 403" do
      candidacy = create(:candidacy, job_posting: posting)
      log_in_as(create(:student_user))

      post_match(candidacy.id)

      expect(response).to have_http_status(:forbidden)
      expect(candidacy.reload).to be_unmatched
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "200 と、マッチしたあとの募集の状態（形D）を返す。マッチした日時が入り、スレッドができる" do
        candidacy = create(:candidacy, job_posting: posting, student_profile: student)

        post_match(candidacy.id)

        expect(response).to have_http_status(:ok)
        candidacy.reload
        expect(candidacy).to be_matched
        expect(candidacy.matched_at).to be_present
        expect(response.parsed_body).to include(
          "id" => posting.id, "status" => "published",
          "candidacy" => include("id" => candidacy.id, "status" => "matched", "tag" => "matched"),
          # マッチしたあとは、押せるボタンがなくなる
          "available_actions" => []
        )
        expect(MessageThread.where(company_profile: company, student_profile: student).count).to eq(1)
      end

      it "見送りの応募にもマッチできる" do
        candidacy = create(:candidacy, job_posting: posting, student_profile: student, status: :declined)

        post_match(candidacy.id)

        expect(response).to have_http_status(:ok)
        expect(candidacy.reload).to be_matched
      end

      it "同じ企業の別の募集で、先にスレッドができていれば、増やさずにそのまま使う" do
        MessageThread.create!(company_profile: company, student_profile: student)
        candidacy = create(:candidacy, job_posting: posting, student_profile: student)

        post_match(candidacy.id)

        expect(response).to have_http_status(:ok)
        expect(MessageThread.where(company_profile: company, student_profile: student).count).to eq(1)
      end

      # 今の状態ではできない（権限_バリデーション.md の 17-2-1）
      {
        "スカウトから始まったやりとり（学生が応じたときにマッチする）" => { origin: :scout },
        "もうマッチ済みのやりとり" => { status: :matched }
      }.each do |label, attributes|
        it "#{label}なら 409。状態は変わらず、スレッドもできない" do
          candidacy = create(:candidacy, job_posting: posting, student_profile: student, **attributes)

          post_match(candidacy.id)

          expect(response).to have_http_status(:conflict)
          expect(response.parsed_body["message"]).to eq("この操作は今はできません。画面を読み込み直してください")
          expect(candidacy.reload.status).to eq((attributes[:status] || :unmatched).to_s)
          expect(MessageThread.count).to eq(0)
        end
      end

      it "募集が掲載中でなければ 409" do
        candidacy = create(:candidacy, job_posting: posting, student_profile: student)
        posting.update!(status: :closed)

        post_match(candidacy.id)

        expect(response).to have_http_status(:conflict)
        expect(candidacy.reload).to be_unmatched
      end

      # 必須テスト：他社のやりとりの番号は 404（16-1-10）
      it "他社の募集へのやりとりの番号なら 404。状態は変わらない" do
        other_candidacy = create(:candidacy)

        post_match(other_candidacy.id)

        expect(response).to have_http_status(:not_found)
        expect(other_candidacy.reload).to be_unmatched
      end

      it "存在しない番号なら 404" do
        post_match(0)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
