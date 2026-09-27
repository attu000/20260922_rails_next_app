require "rails_helper"

# ㉔ POST /api/company/scouts（スカウト）のテスト。
# 必須テスト「学生が企業の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1・17-3
RSpec.describe "スカウト（/api/company/scouts）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:company) { company_user.company_profile }
  let(:posting) { create(:job_posting, :published, company_profile: company) }
  let(:student) { create(:student_user).student_profile }
  let(:body) { "はじめまして。バックエンドの募集にご興味はありませんか。" }

  # スカウトを送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def post_scout(params)
    post "/api/company/scouts", params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  # スカウトで作られるもの4つ。失敗したときに、どれも作られていないことを確かめる
  def created_records_count
    [ Candidacy.count, MessageThread.count, Message.count, ScoutMessage.count ]
  end

  it "未ログインなら 401" do
    post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: body)

    expect(response).to have_http_status(:unauthorized)
  end

  it "学生なら 403" do
    log_in_as(create(:student_user))

    post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: body)

    expect(response).to have_http_status(:forbidden)
    expect(Candidacy.count).to eq(0)
  end

  context "ログインしている企業" do
    before { log_in_as(company_user) }

    it "201 と、スカウトしたあとの募集の状態（形D）を返す" do
      post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:created)
      candidacy = Candidacy.sole
      expect(response.parsed_body).to eq(
        "id" => posting.id, "title" => posting.title, "status" => "published",
        "candidacy" => {
          "id" => candidacy.id, "origin" => "scout", "status" => "unmatched",
          # マッチ理由は学生がマッチしたときに選ぶので、スカウトした直後は空
          "tag" => "scouted", "reasons" => [], "matched_at" => nil
        },
        # スカウトしたあとは「見送る」だけ（企業はスカウトにマッチできない）
        "available_actions" => [ "decline" ]
      )
    end

    it "やりとり・スレッド・メッセージ・スカウトメッセージを1つずつ作り、スレッドに最後のメッセージの日時を入れる" do
      post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: body)

      candidacy = Candidacy.sole
      expect(candidacy).to have_attributes(job_posting: posting, student_profile: student, origin: "scout", status: "unmatched")

      thread = MessageThread.sole
      expect(thread).to have_attributes(company_profile: company, student_profile: student)

      message = Message.sole
      expect(message).to have_attributes(message_thread: thread, sender_user: company_user, body: body)
      expect(candidacy.scout_message.message).to eq(message)
      expect(thread.last_message_at).to eq(message.created_at)
    end

    it "同じ学生とのスレッドが先にあれば、増やさずに、そのスレッドにスカウト文を足す" do
      thread = MessageThread.create!(company_profile: company, student_profile: student)

      post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:created)
      expect(MessageThread.sole).to eq(thread)
      expect(Message.sole.message_thread).to eq(thread)
    end

    # 必須テスト：他社の募集の番号は 404（16-1-10）
    it "他社の募集の番号なら 404。何も作られない" do
      other_company_posting = create(:job_posting, :published)

      post_scout(job_posting_id: other_company_posting.id, student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:not_found)
      expect(created_records_count).to eq([ 0, 0, 0, 0 ])
    end

    it "存在しない募集の番号なら 404" do
      post_scout(job_posting_id: 0, student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:not_found)
    end

    it "存在しない学生の番号なら 404" do
      post_scout(job_posting_id: posting.id, student_profile_id: 0, body: body)

      expect(response).to have_http_status(:not_found)
    end

    # 今の状態ではできない（権限_バリデーション.md の 17-2-1）
    it "募集が掲載中でなければ 409。何も作られない" do
      closed = create(:job_posting, :closed, company_profile: company)

      post_scout(job_posting_id: closed.id, student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["message"]).to eq("この操作は今はできません。画面を読み込み直してください")
      expect(created_records_count).to eq([ 0, 0, 0, 0 ])
    end

    it "この募集×学生のやりとりがもうあれば（応募済みなど）409。何も増えない" do
      create(:candidacy, job_posting: posting, student_profile: student)

      post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:conflict)
      expect(created_records_count).to eq([ 1, 0, 0, 0 ])
    end

    # 確かめる順番は「番号（404）→ 状態（409）→ 入力（422）」（16-3-6）
    it "掲載中でない募集で、スカウト文も空なら、状態の確かめが先で 409" do
      closed = create(:job_posting, :closed, company_profile: company)

      post_scout(job_posting_id: closed.id, student_profile_id: student.id, body: "")

      expect(response).to have_http_status(:conflict)
    end

    it "スカウト文が空なら 422。「スカウト文を入力してください」を返し、何も作られない" do
      post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("body" => [ "スカウト文を入力してください" ])
      expect(created_records_count).to eq([ 0, 0, 0, 0 ])
    end

    it "スカウト文が送られていなくても、同じく 422 の「スカウト文を入力してください」" do
      post_scout(job_posting_id: posting.id, student_profile_id: student.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("body" => [ "スカウト文を入力してください" ])
    end

    it "スカウト文が2,001文字なら 422" do
      post_scout(job_posting_id: posting.id, student_profile_id: student.id, body: "あ" * 2001)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].keys).to eq([ "body" ])
      expect(created_records_count).to eq([ 0, 0, 0, 0 ])
    end

    it "job_posting_id がなければ 422" do
      post_scout(student_profile_id: student.id, body: body)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
