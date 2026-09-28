require "rails_helper"

# 企業の通知の窓口のテスト。㊷ GET /api/company/notifications（通知の一覧）、
# ㊸ POST /api/company/notifications/:id/read（1件を既読にする）、㊹ POST /api/company/notifications/read_all（すべて既読にする）。
# 必須テスト「見てよい範囲の外の番号は 404」（技術構成.md の 3-3 D-1、API設計.md の 16-1-10）を含む。
# 詳しくは design/designs/API設計.md の 16-3-8、権限_バリデーション.md の 17-1
RSpec.describe "企業の通知（/api/company/notifications）", type: :request do
  let(:company_user) { create(:company_user) }

  # 既読にする。テストでも CSRF 対策は有効なので、合言葉を付ける
  def post_read(path)
    post path, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  describe "㊷ 通知の一覧" do
    it "未ログインなら 401" do
      get "/api/company/notifications"

      expect(response).to have_http_status(:unauthorized)
    end

    it "学生なら 403" do
      log_in_as(create(:student_user))

      get "/api/company/notifications"

      expect(response).to have_http_status(:forbidden)
    end

    context "ログインしている企業" do
      before { log_in_as(company_user) }

      it "自社宛ての通知だけを、新しい順に返す" do
        older = create(:notification, user: company_user, created_at: 2.days.ago)
        newer = create(:notification, user: company_user, created_at: 1.hour.ago)
        # 他社宛て
        create(:notification, created_at: Time.current)

        get "/api/company/notifications"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ newer.id, older.id ])
      end

      it "1行は id・kind・body・link_path・read_at・created_at。ページの情報も返す" do
        notification = create(:notification, user: company_user)

        get "/api/company/notifications"

        item = response.parsed_body["items"].first
        expect(item.keys).to contain_exactly("id", "kind", "body", "link_path", "read_at", "created_at")
        expect(item).to include(
          "id" => notification.id,
          "kind" => "recommended_student",
          "body" => notification.body,
          "link_path" => notification.link_path,
          "read_at" => nil
        )
        expect(response.parsed_body["pagination"]).to eq(
          "page" => 1, "per_page" => 20, "total_count" => 1, "total_pages" => 1
        )
      end
    end
  end

  describe "㊸ 1件を既読にする" do
    before { log_in_as(company_user) }

    it "未読を既読にして 204" do
      notification = create(:notification, user: company_user)

      post_read("/api/company/notifications/#{notification.id}/read")

      expect(response).to have_http_status(:no_content)
      expect(notification.reload.read_at).to be_present
    end

    it "すでに既読なら、最初に読んだ日時のまま 204" do
      read_at = Time.zone.parse("2026-09-20 10:00")
      notification = create(:notification, user: company_user, read_at: read_at)

      post_read("/api/company/notifications/#{notification.id}/read")

      expect(response).to have_http_status(:no_content)
      expect(notification.reload.read_at).to eq(read_at)
    end

    it "他社宛ての通知の番号なら 404 で、既読にならない" do
      others = create(:notification)

      post_read("/api/company/notifications/#{others.id}/read")

      expect(response).to have_http_status(:not_found)
      expect(others.reload.read_at).to be_nil
    end

    it "ない番号なら 404" do
      post_read("/api/company/notifications/0/read")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "㊹ すべて既読にする" do
    before { log_in_as(company_user) }

    it "自社宛ての未読がすべて既読になり 204。他社宛ては未読のまま" do
      mine = create_list(:notification, 2, user: company_user)
      others = create(:notification)

      post_read("/api/company/notifications/read_all")

      expect(response).to have_http_status(:no_content)
      expect(mine.map { |notification| notification.reload.read_at }).to all(be_present)
      expect(others.reload.read_at).to be_nil
    end
  end
end
