require "rails_helper"

# 企業のメッセージの窓口のテスト。㊱ GET /api/company/message_threads（スレッド一覧）、
# ㊲ GET /api/company/students/:student_id/message_thread（チャット）、
# ㊳ POST /api/company/students/:student_id/message_thread/messages（送信）。
# 必須テスト「学生が企業の窓口を呼ぶと 403」「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-7、権限_バリデーション.md の 17-2-3
RSpec.describe "企業のメッセージ（/api/company/message_threads・/api/company/students/:id/message_thread）", type: :request do
  let(:company_user) { create(:company_user) }
  let(:company) { company_user.company_profile }
  let(:student) { create(:student_user).student_profile }
  let(:posting) { create(:job_posting, :published, company_profile: company) }
  let(:thread) { create(:message_thread, company_profile: company, student_profile: student) }

  # 送信する。テストでも CSRF 対策は有効なので、合言葉を付ける
  def post_message(student_id, params)
    post "/api/company/students/#{student_id}/message_thread/messages",
         params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  # この学生とマッチしている状態にする
  def match_student
    create(:candidacy, job_posting: posting, student_profile: student, status: :matched)
  end

  describe "㊱ スレッド一覧" do
    it "未ログインなら 401" do
      get "/api/company/message_threads"

      expect(response).to have_http_status(:unauthorized)
    end

    it "学生なら 403" do
      log_in_as(create(:student_user))

      get "/api/company/message_threads"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "自社のスレッドだけを、最後のメッセージの新しい順に返す。メッセージがなければ作った日時で比べる（PR221）" do
        older = create(:message_thread, company_profile: company, last_message_at: 3.days.ago)
        newer = create(:message_thread, company_profile: company, last_message_at: 1.hour.ago)
        no_message = create(:message_thread, company_profile: company, last_message_at: nil)
        no_message.update_columns(created_at: 2.days.ago)
        # 他社のスレッド
        create(:message_thread, last_message_at: Time.current)

        get "/api/company/message_threads"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ newer.id, no_message.id, older.id ])
      end

      it "1行は id・相手の学生（partner）・last_message_at。ページの情報も返す" do
        thread.update!(last_message_at: Time.zone.parse("2026-09-22 10:00"))

        get "/api/company/message_threads"

        expect(response.parsed_body["items"].sole).to eq(
          "id" => thread.id,
          "partner" => { "id" => student.id, "name" => student.name, "icon_url" => nil },
          "last_message_at" => "2026-09-22T10:00:00.000+09:00"
        )
        expect(response.parsed_body["pagination"]).to eq(
          "page" => 1, "per_page" => 20, "total_count" => 1, "total_pages" => 1
        )
      end
    end
  end

  describe "㊲ チャット" do
    it "学生なら 403" do
      log_in_as(create(:student_user))

      get "/api/company/students/#{thread.student_profile_id}/message_thread"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "相手・送れるか・メッセージ（古い順）を返す。スカウト文には募集が付き、ふつうのメッセージの scout は null" do
        scout = Candidacy.send_scout(posting, student, "はじめまして")
        scout.update!(status: :matched)
        # スレッドはスカウトを送ったときにできている
        reply = create(:message, message_thread: MessageThread.sole, sender_user: student.user, body: "よろしくお願いします")
        scout_message = scout.scout_message.message
        # スカウト文より後に返事が来たことにする
        reply.update_columns(created_at: scout_message.created_at + 1.minute)

        get "/api/company/students/#{student.id}/message_thread"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "partner" => { "id" => student.id, "name" => student.name, "icon_url" => nil },
          "can_send" => true,
          "messages" => [
            {
              "id" => scout_message.id, "is_mine" => true, "body" => "はじめまして",
              "created_at" => scout_message.created_at.as_json,
              "scout" => { "job_posting" => { "id" => posting.id, "title" => posting.title } }
            },
            {
              "id" => reply.id, "is_mine" => false, "body" => "よろしくお願いします",
              "created_at" => reply.reload.created_at.as_json, "scout" => nil
            }
          ]
        )
      end

      it "スカウトしただけ（まだマッチしていない）なら can_send は false" do
        Candidacy.send_scout(posting, student, "はじめまして")

        get "/api/company/students/#{student.id}/message_thread"

        expect(response.parsed_body["can_send"]).to be(false)
      end

      # 必須テスト：見てよい範囲の外は 404（16-1-10）
      it "他社とその学生のスレッドしかなければ 404" do
        other_thread = create(:message_thread, student_profile: student)

        get "/api/company/students/#{other_thread.student_profile_id}/message_thread"

        expect(response).to have_http_status(:not_found)
      end

      it "スレッドがまだない学生なら 404" do
        get "/api/company/students/#{student.id}/message_thread"

        expect(response).to have_http_status(:not_found)
      end

      it "存在しない学生の番号なら 404" do
        get "/api/company/students/0/message_thread"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "㊳ 送信" do
    it "学生なら 403。何も作られない" do
      thread
      log_in_as(create(:student_user))

      post_message(student.id, body: "よろしくお願いします")

      expect(response).to have_http_status(:forbidden)
      expect(Message.count).to eq(0)
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "マッチしていれば 201 と、作ったメッセージ1件を返す。スレッドの最後のメッセージの日時も新しくなる" do
        thread
        match_student

        post_message(student.id, body: "面談の日程を決めましょう")

        expect(response).to have_http_status(:created)
        message = Message.sole
        expect(message).to have_attributes(message_thread: thread, sender_user: company_user, body: "面談の日程を決めましょう")
        expect(response.parsed_body).to eq(
          "id" => message.id, "is_mine" => true, "body" => "面談の日程を決めましょう",
          "created_at" => message.created_at.as_json, "scout" => nil
        )
        expect(thread.reload.last_message_at).to eq(message.created_at)
      end

      it "まだマッチしていなければ 409。何も作られない" do
        Candidacy.send_scout(posting, student, "はじめまして")

        post_message(student.id, body: "よろしくお願いします")

        expect(response).to have_http_status(:conflict)
        # スカウト文の1通だけ
        expect(Message.count).to eq(1)
      end

      it "本文が空なら 422。「本文を入力してください」を返し、何も作られない" do
        thread
        match_student

        post_message(student.id, body: "")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to eq("body" => [ "本文を入力してください" ])
        expect(Message.count).to eq(0)
      end

      it "本文が送られていなくても、同じく 422 の「本文を入力してください」" do
        thread
        match_student

        post_message(student.id, {})

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to eq("body" => [ "本文を入力してください" ])
      end

      # 確かめる順番は「番号（404）→ 状態（409）→ 入力（422）」
      it "スレッドがない学生なら、マッチしていなくても 404" do
        post_message(student.id, body: "よろしくお願いします")

        expect(response).to have_http_status(:not_found)
      end

      it "他社とその学生のスレッドしかなければ 404" do
        other_thread = create(:message_thread, student_profile: student)

        post_message(other_thread.student_profile_id, body: "よろしくお願いします")

        expect(response).to have_http_status(:not_found)
        expect(Message.count).to eq(0)
      end
    end
  end
end
