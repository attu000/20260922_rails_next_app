require "rails_helper"

# 学生のメッセージの窓口のテスト。㊴ GET /api/student/message_threads（スレッド一覧）、
# ㊵ GET /api/student/companies/:company_id/message_thread（チャット）、
# ㊶ POST /api/student/companies/:company_id/message_thread/messages（送信）。
# 必須テスト「企業が学生の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-7、権限_バリデーション.md の 17-2-3
RSpec.describe "学生のメッセージ（/api/student/message_threads・/api/student/companies/:id/message_thread）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:student) { student_user.student_profile }
  let(:company) { create(:company_user).company_profile }
  let(:posting) { create(:job_posting, :published, company_profile: company) }
  let(:thread) { create(:message_thread, company_profile: company, student_profile: student) }

  # 送信する。テストでも CSRF 対策は有効なので、合言葉を付ける
  def post_message(company_id, params)
    post "/api/student/companies/#{company_id}/message_thread/messages",
         params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  # この企業とマッチしている状態にする
  def match_company
    create(:candidacy, job_posting: posting, student_profile: student, status: :matched)
  end

  describe "㊴ スレッド一覧" do
    it "未ログインなら 401" do
      get "/api/student/message_threads"

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら 403" do
      log_in_as(create(:company_user))

      get "/api/student/message_threads"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている学生" do
      before { log_in_as(student_user) }

      it "自分のスレッドだけを、最後のメッセージの新しい順に返す。メッセージがなければ作った日時で比べる（PR221）" do
        older = create(:message_thread, student_profile: student, last_message_at: 3.days.ago)
        newer = create(:message_thread, student_profile: student, last_message_at: 1.hour.ago)
        no_message = create(:message_thread, student_profile: student, last_message_at: nil)
        no_message.update_columns(created_at: 2.days.ago)
        # ほかの学生のスレッド
        create(:message_thread, last_message_at: Time.current)

        get "/api/student/message_threads"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ newer.id, no_message.id, older.id ])
      end

      it "1行は id・相手の企業（partner）・last_message_at。ページの情報も返す" do
        thread.update!(last_message_at: Time.zone.parse("2026-09-22 10:00"))

        get "/api/student/message_threads"

        expect(response.parsed_body["items"].sole).to eq(
          "id" => thread.id,
          "partner" => { "id" => company.id, "name" => company.name, "icon_url" => nil },
          "last_message_at" => "2026-09-22T10:00:00.000+09:00"
        )
        expect(response.parsed_body["pagination"]).to eq(
          "page" => 1, "per_page" => 20, "total_count" => 1, "total_pages" => 1
        )
      end
    end
  end

  describe "㊵ チャット" do
    it "企業なら 403" do
      log_in_as(create(:company_user))

      get "/api/student/companies/#{thread.company_profile_id}/message_thread"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている学生" do
      before { log_in_as(student_user) }

      # スカウト文をマッチ前に読める（権限_バリデーション.md の 17-2-3）
      it "スカウトが届いただけでも開ける。スカウト文は相手が送ったもので募集が付き、まだ送れない" do
        scout = Candidacy.send_scout(posting, student, "はじめまして")
        scout_message = scout.scout_message.message

        get "/api/student/companies/#{company.id}/message_thread"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "partner" => { "id" => company.id, "name" => company.name, "icon_url" => nil },
          "can_send" => false,
          "messages" => [
            {
              "id" => scout_message.id, "is_mine" => false, "body" => "はじめまして",
              "created_at" => scout_message.created_at.as_json,
              "scout" => { "job_posting" => { "id" => posting.id, "title" => posting.title } }
            }
          ]
        )
      end

      it "マッチしていれば送れる。自分が送ったメッセージは is_mine が true で、scout は null" do
        match_company
        mine = create(:message, message_thread: thread, sender_user: student_user, body: "よろしくお願いします")

        get "/api/student/companies/#{company.id}/message_thread"

        body = response.parsed_body
        expect(body["can_send"]).to be(true)
        expect(body["messages"].sole).to include("id" => mine.id, "is_mine" => true, "scout" => nil)
      end

      # 必須テスト：見てよい範囲の外は 404（16-1-10）
      it "ほかの学生とその企業のスレッドしかなければ 404" do
        other_thread = create(:message_thread, company_profile: company)

        get "/api/student/companies/#{other_thread.company_profile_id}/message_thread"

        expect(response).to have_http_status(:not_found)
      end

      it "スレッドがまだない企業（応募しただけなど）なら 404" do
        create(:candidacy, job_posting: posting, student_profile: student)

        get "/api/student/companies/#{company.id}/message_thread"

        expect(response).to have_http_status(:not_found)
      end

      it "存在しない企業の番号なら 404" do
        get "/api/student/companies/0/message_thread"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "㊶ 送信" do
    it "企業なら 403。何も作られない" do
      thread
      log_in_as(create(:company_user))

      post_message(company.id, body: "よろしくお願いします")

      expect(response).to have_http_status(:forbidden)
      expect(Message.count).to eq(0)
    end

    context "ログインしている学生" do
      before { log_in_as(student_user) }

      it "マッチしていれば 201 と、作ったメッセージ1件を返す。スレッドの最後のメッセージの日時も新しくなる" do
        thread
        match_company

        post_message(company.id, body: "面談の日程、承知しました")

        expect(response).to have_http_status(:created)
        message = Message.sole
        expect(message).to have_attributes(message_thread: thread, sender_user: student_user, body: "面談の日程、承知しました")
        expect(response.parsed_body).to eq(
          "id" => message.id, "is_mine" => true, "body" => "面談の日程、承知しました",
          "created_at" => message.created_at.as_json, "scout" => nil
        )
        expect(thread.reload.last_message_at).to eq(message.created_at)
      end

      it "スカウトが届いただけ（まだマッチしていない）なら 409。スカウト文の1通だけのまま" do
        Candidacy.send_scout(posting, student, "はじめまして")

        post_message(company.id, body: "よろしくお願いします")

        expect(response).to have_http_status(:conflict)
        expect(Message.count).to eq(1)
      end

      it "本文が空なら 422。「本文を入力してください」を返し、何も作られない" do
        thread
        match_company

        post_message(company.id, body: "")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to eq("body" => [ "本文を入力してください" ])
        expect(Message.count).to eq(0)
      end

      it "本文が送られていなくても、同じく 422 の「本文を入力してください」" do
        thread
        match_company

        post_message(company.id, {})

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to eq("body" => [ "本文を入力してください" ])
      end

      # 確かめる順番は「番号（404）→ 状態（409）→ 入力（422）」
      it "スレッドがない企業なら 404" do
        post_message(company.id, body: "よろしくお願いします")

        expect(response).to have_http_status(:not_found)
      end

      it "ほかの学生とその企業のスレッドしかなければ 404" do
        other_thread = create(:message_thread, company_profile: company)

        post_message(other_thread.company_profile_id, body: "よろしくお願いします")

        expect(response).to have_http_status(:not_found)
        expect(Message.count).to eq(0)
      end
    end
  end
end
