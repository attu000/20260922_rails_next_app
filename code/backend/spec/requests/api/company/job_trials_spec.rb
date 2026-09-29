require "rails_helper"

# ㊾ GET /api/company/job_trials/:id（企業向けのプチ職業体験の講座の中身）のテスト。
# 講座はすべての企業が見てよいので、「見てよい範囲の外」は存在しない番号だけ（API設計.md の 16-1-10）。
# 詳しくは design/designs/API設計.md の 16-3-9
RSpec.describe "企業向けのプチ職業体験の講座（/api/company/job_trials/:id）", type: :request do
  let(:job_trial) { create(:job_trial, :with_hurdles) }

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      get "/api/company/job_trials/#{job_trial.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "学生なら 403" do
      log_in_as(create(:student_user))

      get "/api/company/job_trials/#{job_trial.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "講座の中身" do
    before { log_in_as(create(:company_user)) }

    it "学生向けと同じ形から自己分析を除き、選択肢に正解と解説を加えて返す（PR373）" do
      create(:self_analysis, job_trial: job_trial)

      get "/api/company/job_trials/#{job_trial.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly("id", "title", "job_middle_category_id", "work_process_ids", "intro", "hurdles")
      expect(body["hurdles"].map { |hurdle| hurdle["id"] }).to eq(job_trial.hurdles.ids)
      expect(body["hurdles"].first["choices"]).to eq([
        { "key" => "A", "body" => "選択肢A", "correct" => true, "explanation" => "Aの解説" },
        { "key" => "B", "body" => "選択肢B", "correct" => false, "explanation" => "Bの解説" }
      ])
    end

    it "存在しない番号なら 404" do
      get "/api/company/job_trials/0"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["message"]).to eq("見つかりません")
    end
  end
end
