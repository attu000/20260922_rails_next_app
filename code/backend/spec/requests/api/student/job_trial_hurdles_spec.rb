require "rails_helper"

# ㊼ POST /api/student/job_trial_hurdles/:id/check（問題の正否の判定）のテスト。
# 詳しくは design/designs/API設計.md の 16-3-9
RSpec.describe "プチ職業体験の問題の正否の判定（/api/student/job_trial_hurdles/:id/check）", type: :request do
  let(:hurdle) { create(:job_trial_hurdle) }

  # 答えを送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def check(id: hurdle.id, params: { choice: "A" })
    post "/api/student/job_trial_hurdles/#{id}/check",
         params: params,
         headers: { "X-CSRF-Token" => csrf_token },
         as: :json
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      check

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら 403" do
      log_in_as(create(:company_user))

      check

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "判定" do
    before { log_in_as(create(:student_user)) }

    it "正解の選択肢なら、正解とその選択肢の解説を返す" do
      check(params: { choice: "A" })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("correct" => true, "explanation" => "Aの解説")
    end

    it "不正解の選択肢なら、不正解とその選択肢の解説を返す（正解の選択肢は返さない）" do
      check(params: { choice: "B" })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("correct" => false, "explanation" => "Bの解説")
    end

    it "何も記録しない" do
      hurdle

      expect { check }.not_to(change { [ JobTrialHurdle.maximum(:updated_at), SelfAnalysis.count ] })
    end

    it "その問題にない選択肢なら 422（PR395）" do
      check(params: { choice: "Z" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("choice" => [ "選択肢は、この問題の選択肢から選んでください" ])
    end

    it "選択肢が送られていなければ 422" do
      check(params: {})

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("choice")
    end

    it "存在しない番号なら 404" do
      check(id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
