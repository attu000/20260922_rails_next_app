require "rails_helper"

# ㉛ POST /api/student/candidacies（応募）のテスト。
# 必須テスト「企業が学生の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1・17-3-4・17-3-6
RSpec.describe "応募（POST /api/student/candidacies）", type: :request do
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
end
