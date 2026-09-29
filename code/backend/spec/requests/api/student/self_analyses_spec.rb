require "rails_helper"

# ㊽ PUT /api/student/job_trials/:job_trial_id/self_analysis（自己分析の保存）のテスト。
# 詳しくは design/designs/API設計.md の 16-3-9、サービス概要_コンセプト.md の 12-4
RSpec.describe "プチ職業体験の自己分析の保存（/api/student/job_trials/:job_trial_id/self_analysis）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:student) { student_user.student_profile }
  let(:job_trial) { create(:job_trial, :with_hurdles) }
  let(:hurdles) { job_trial.hurdles.to_a }
  let(:valid_params) do
    {
      strength_hurdle_id: hurdles[0].id,
      strength_reason: "仕様の言葉を確かめる癖があるから",
      growth_hurdle_id: hurdles[3].id,
      growth_reason: "curiosity",
      growth_detail: "原因を順に消していくのが楽しい",
      next_step: "不具合の報告の書き方を知りたい"
    }
  end

  # 自己分析を送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def save(job_trial_id: job_trial.id, params: valid_params)
    put "/api/student/job_trials/#{job_trial_id}/self_analysis",
        params: params,
        headers: { "X-CSRF-Token" => csrf_token },
        as: :json
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      save

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら 403" do
      log_in_as(create(:company_user))

      save

      expect(response).to have_http_status(:forbidden)
      expect(SelfAnalysis.count).to eq(0)
    end
  end

  describe "保存" do
    before { log_in_as(student_user) }

    it "初めてなら作り、200 と保存した自己分析を返す" do
      save

      expect(response).to have_http_status(:ok)
      self_analysis = SelfAnalysis.sole
      expect(self_analysis).to have_attributes(student_profile: student, job_trial: job_trial)
      expect(response.parsed_body).to include(
        "job_trial_id" => job_trial.id,
        "strength_hurdle_id" => hurdles[0].id,
        "strength_reason" => "仕様の言葉を確かめる癖があるから",
        "growth_hurdle_id" => hurdles[3].id,
        "growth_reason" => "curiosity",
        "growth_detail" => "原因を順に消していくのが楽しい",
        "next_step" => "不具合の報告の書き方を知りたい",
        "same_hurdle" => false
      )
      expect(response.parsed_body.keys).to include("created_at", "updated_at")
    end

    it "2回目は上書きし、200 を返す。1人×1講座に1件のまま（PR371）" do
      save
      save(params: valid_params.merge(growth_hurdle_id: hurdles[0].id, next_step: "書き直した"))

      expect(response).to have_http_status(:ok)
      expect(SelfAnalysis.count).to eq(1)
      expect(SelfAnalysis.sole).to have_attributes(growth_hurdle_id: hurdles[0].id, next_step: "書き直した")
      expect(response.parsed_body["same_hurdle"]).to be(true)
    end

    it "学生や講座の番号を送っても、自分のこの講座の自己分析として保存する" do
      other_student = create(:student_user).student_profile
      save(params: valid_params.merge(student_profile_id: other_student.id, job_trial_id: 0))

      expect(response).to have_http_status(:ok)
      expect(SelfAnalysis.sole).to have_attributes(student_profile: student, job_trial: job_trial)
    end

    it "ほかの講座のハードルを選ぶと 422 で、保存しない" do
      other_hurdle = create(:job_trial, :with_hurdles).hurdles.first

      save(params: valid_params.merge(strength_hurdle_id: other_hurdle.id))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq(
        "strength_hurdle_id" => [ "得意なハードルは、この講座のハードルから選んでください" ]
      )
      expect(SelfAnalysis.count).to eq(0)
    end

    it "記述が空・長すぎる、理由の種類が知らない値なら 422。前の自己分析は変わらない" do
      save
      save(params: valid_params.merge(next_step: "", growth_detail: "あ" * 401, growth_reason: "unknown"))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].keys).to contain_exactly("next_step", "growth_detail", "growth_reason")
      expect(SelfAnalysis.sole.next_step).to eq("不具合の報告の書き方を知りたい")
    end

    it "存在しない講座の番号なら 404" do
      save(job_trial_id: 0)

      expect(response).to have_http_status(:not_found)
    end

    it "同時に2回送られて「1人×1講座に1件」に弾かれたら 409" do
      allow(SelfAnalysis).to receive(:save_for).and_raise(ConflictError)

      save

      expect(response).to have_http_status(:conflict)
    end
  end
end
