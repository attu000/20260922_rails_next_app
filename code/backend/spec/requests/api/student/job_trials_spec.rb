require "rails_helper"

# ㊺ GET /api/student/job_trials（プチ職業体験の講座の一覧）、㊻ GET /api/student/job_trials/:id（講座の中身）のテスト。
# 講座はすべての学生が見てよいので、「見てよい範囲の外」は存在しない番号だけ。自己分析は自分の分だけ返す（API設計.md の 16-1-10）。
# 詳しくは design/designs/API設計.md の 16-3-9
RSpec.describe "学生のプチ職業体験（/api/student/job_trials）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:student) { student_user.student_profile }
  let(:other_student) { create(:student_user).student_profile }

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      get "/api/student/job_trials"

      expect(response).to have_http_status(:unauthorized)
    end

    it "企業なら 403" do
      log_in_as(create(:company_user))

      get "/api/student/job_trials"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "㊺ 講座の一覧" do
    before { log_in_as(student_user) }

    it "すべての講座を、講座の表示順で、決めた形で返す。工程は工程の表示順" do
      second = create(:job_trial, :with_hurdles, position: 2)
      first = create(:job_trial, :with_hurdles, position: 1)
      later_process = create(:work_process, position: 9)
      earlier_process = create(:work_process, position: 4)
      first.work_processes = [ later_process, earlier_process ]

      get "/api/student/job_trials"

      expect(response).to have_http_status(:ok)
      items = response.parsed_body["items"]
      expect(items.map { |item| item["id"] }).to eq([ first.id, second.id ])
      expect(items.first).to eq(
        "id" => first.id,
        "title" => first.title,
        "job_middle_category_id" => first.job_middle_category_id,
        "work_process_ids" => [ earlier_process.id, later_process.id ],
        "completed" => false
      )
    end

    it "completed は、自分がその講座の自己分析を送っているときだけ true。ほかの学生の自己分析では true にならない" do
      mine = create(:job_trial, :with_hurdles, position: 1)
      others = create(:job_trial, :with_hurdles, position: 2)
      create(:self_analysis, student_profile: student, job_trial: mine)
      create(:self_analysis, student_profile: other_student, job_trial: others)

      get "/api/student/job_trials"

      expect(response.parsed_body["items"].map { |item| item["completed"] }).to eq([ true, false ])
    end

    it "講座がなければ空の配列" do
      get "/api/student/job_trials"

      expect(response.parsed_body).to eq("items" => [])
    end
  end

  describe "㊻ 講座の中身" do
    before { log_in_as(student_user) }

    let(:job_trial) { create(:job_trial, :with_hurdles) }
    let(:hurdles) { job_trial.hurdles.to_a }

    it "講座とハードルを、決めた形で返す。ハードルは講座の中の順番" do
      # 順番どおりに並ぶかを見るため、後に並ぶハードルを先に作った講座にする
      trial = create(:job_trial)
      later = create(:job_trial_hurdle, job_trial: trial, position: 2)
      earlier = create(:job_trial_hurdle, job_trial: trial, position: 1)

      get "/api/student/job_trials/#{trial.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly(
        "id", "title", "job_middle_category_id", "work_process_ids", "intro", "hurdles", "self_analysis"
      )
      expect(body).to include("id" => trial.id, "title" => trial.title, "intro" => "はじめに", "self_analysis" => nil)
      expect(body["hurdles"].map { |hurdle| hurdle["id"] }).to eq([ earlier.id, later.id ])
      expect(body["hurdles"].first).to eq(
        "id" => earlier.id, "name" => earlier.name,
        "overview" => "概要", "difficulty" => "難しさ", "tips" => "コツ", "example" => "具体例", "goal" => "ゴール",
        "question" => "問題",
        "choices" => [ { "key" => "A", "body" => "選択肢A" }, { "key" => "B", "body" => "選択肢B" } ]
      )
    end

    it "選択肢に正解と解説を入れない（PR377）" do
      get "/api/student/job_trials/#{job_trial.id}"

      choices = response.parsed_body["hurdles"].flat_map { |hurdle| hurdle["choices"] }
      expect(choices).to all(satisfy { |choice| choice.keys == %w[key body] })
    end

    it "自分の自己分析があれば、保存の窓口の返事と同じ形で返す" do
      create(:self_analysis, student_profile: student, job_trial: job_trial,
                             strength_hurdle: hurdles[1], growth_hurdle: hurdles[1])

      get "/api/student/job_trials/#{job_trial.id}"

      expect(response.parsed_body["self_analysis"]).to include(
        "job_trial_id" => job_trial.id,
        "strength_hurdle_id" => hurdles[1].id,
        "growth_hurdle_id" => hurdles[1].id,
        "growth_reason" => "curiosity",
        "same_hurdle" => true
      )
      expect(response.parsed_body["self_analysis"].keys).to contain_exactly(
        "job_trial_id", "strength_hurdle_id", "strength_reason", "growth_hurdle_id", "growth_reason",
        "growth_detail", "next_step", "same_hurdle", "created_at", "updated_at"
      )
    end

    it "ほかの学生の自己分析しかなければ null" do
      create(:self_analysis, student_profile: other_student, job_trial: job_trial)

      get "/api/student/job_trials/#{job_trial.id}"

      expect(response.parsed_body["self_analysis"]).to be_nil
    end

    it "存在しない番号なら 404" do
      get "/api/student/job_trials/0"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["message"]).to eq("見つかりません")
    end
  end
end
