require "rails_helper"

# ⑮ GET /api/student/profile（表示）と ⑯ PATCH /api/student/profile（保存）、種別の入口の確認のテスト。
# 詳しくは design/designs/API設計.md の 16-1-6・16-1-10、16-3 ⑮⑯、権限_バリデーション.md の 17-3-4。
# この窓口のパスには番号がないので、「見てよい範囲の外の番号は 404」のテストは対象外（自分のプロフィールしか扱えない）
RSpec.describe "学生のプロフィール（/api/student/profile）", type: :request do
  let(:student_user) { create(:student_user) }
  let(:profile) { student_user.student_profile }
  let!(:technology) { create(:technology) }
  let!(:other_technology) { create(:technology) }
  let!(:middle_a) { create(:job_middle_category) }
  let!(:middle_b) { create(:job_middle_category) }
  let!(:prefecture) { create(:prefecture) }
  let!(:university) { create(:university) }
  let!(:department) { create(:department) }

  # 保存を送る。テストでも CSRF 対策は有効なので、合言葉を付ける
  def patch_profile(params)
    patch "/api/student/profile", params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  # 必須の2つ（氏名と活動状況）に、確かめたい項目を足して送る
  def patch_with_required(params)
    patch_profile({ name: "テスト 太郎", activity_status: "skill_up" }.merge(params))
  end

  # プログラミング歴の「その他」の1行
  def other_skill(name, level: "v1")
    { technology_id: nil, other_name: name, years: nil, level: level }
  end

  describe "種別の入口の確認（16-1-6）" do
    it "未ログインなら 401" do
      get "/api/student/profile"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["message"]).to eq("ログインしてください")
    end

    it "企業なら、表示は 403" do
      log_in_as(create(:company_user))

      get "/api/student/profile"

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["message"]).to eq("この操作はできません")
    end

    it "企業なら、保存も 403" do
      log_in_as(create(:company_user))

      patch_profile(name: "書き換え", activity_status: "skill_up")

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "⑮ 表示" do
    it "自分のプロフィールを、決めた形で返す" do
      profile.update!(grade: :undergrad_3, available_from: Date.new(2026, 11, 1))
      profile.interested_job_middle_categories << middle_a
      profile.student_skills.create!(technology: technology, years: 1.5, level: :v2)
      log_in_as(student_user)

      get "/api/student/profile"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly(
        "name", "university_id", "university_other_name", "faculty_id", "department_id", "grade",
        "graduation_year", "prefecture_id", "activity_status",
        "self_pr_strength", "self_pr_weakness", "self_pr_future",
        "work_days_per_week", "work_hours_per_day", "duration_months", "available_from",
        "can_full_remote", "can_partial_remote", "can_onsite", "work_note",
        "personality_pace", "personality_novelty", "personality_collaboration",
        "personality_decision", "personality_atmosphere",
        "interested_job_middle_category_ids", "commutable_prefecture_ids", "skills", "icon_url"
      )
      expect(body["name"]).to eq("テスト 太郎")
      expect(body["grade"]).to eq("undergrad_3")
      expect(body["activity_status"]).to eq("skill_up")
      expect(body["available_from"]).to eq("2026-11-01")
      # 勤務形態の3つは、初期状態で「可能」
      expect(body.values_at("can_full_remote", "can_partial_remote", "can_onsite")).to eq([ true, true, true ])
      expect(body["interested_job_middle_category_ids"]).to eq([ middle_a.id ])
      # 年数は文字列（"1.5"）ではなく数値で返す（16-1-8）
      expect(body["skills"]).to eq([
        { "technology_id" => technology.id, "other_name" => nil, "years" => 1.5, "level" => "v2" }
      ])
      expect(body["icon_url"]).to be_nil
    end
  end

  describe "⑯ 保存" do
    before { log_in_as(student_user) }

    it "全項目を保存でき、⑮と同じ形で返す。職種・都道府県・プログラミング歴は送った内容に置き換わる" do
      profile.interested_job_middle_categories << middle_a
      profile.student_skills.create!(technology: other_technology, level: :v4)

      patch_profile(
        name: "新しい 名前",
        university_id: university.id,
        university_other_name: nil,
        faculty_id: department.faculty_id,
        department_id: department.id,
        grade: "master_1",
        graduation_year: 2028,
        prefecture_id: prefecture.id,
        activity_status: "job_hunting",
        self_pr_strength: "強み",
        self_pr_weakness: "向いていないこと",
        self_pr_future: "やりたいこと",
        work_days_per_week: 3,
        work_hours_per_day: 4,
        duration_months: 6,
        available_from: "2026-11-01",
        can_full_remote: true,
        can_partial_remote: false,
        can_onsite: false,
        work_note: "テスト期間は減らしたい",
        interested_job_middle_category_ids: [ middle_b.id ],
        commutable_prefecture_ids: [ prefecture.id ],
        skills: [
          { technology_id: technology.id, other_name: nil, years: 1.5, level: "v2" },
          other_skill("Elm")
        ]
      )

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["name"]).to eq("新しい 名前")
      expect(body["interested_job_middle_category_ids"]).to eq([ middle_b.id ])
      # 送った順のまま返る
      expect(body["skills"]).to eq([
        { "technology_id" => technology.id, "other_name" => nil, "years" => 1.5, "level" => "v2" },
        { "technology_id" => nil, "other_name" => "Elm", "years" => nil, "level" => "v1" }
      ])

      profile.reload
      expect(profile.university).to eq(university)
      expect(profile.department).to eq(department)
      expect(profile.grade).to eq("master_1")
      expect(profile.activity_status).to eq("job_hunting")
      expect(profile.available_from).to eq(Date.new(2026, 11, 1))
      expect([ profile.can_full_remote, profile.can_partial_remote, profile.can_onsite ]).to eq([ true, false, false ])
      expect(profile.commutable_prefecture_ids).to eq([ prefecture.id ])
      expect(profile.student_skills.map(&:technology_id)).to eq([ technology.id, nil ])
    end

    it "氏名と活動状況だけで保存できる（ほかは任意。その他決め事.md の 5-9）" do
      patch_with_required(
        university_id: nil, faculty_id: nil, department_id: nil, grade: nil, graduation_year: nil,
        prefecture_id: nil, self_pr_strength: "", work_days_per_week: nil, available_from: nil,
        interested_job_middle_category_ids: [], commutable_prefecture_ids: [], skills: []
      )

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["skills"]).to eq([])
    end

    it "プログラミング歴を空の配列で送ると、すべて消える" do
      profile.student_skills.create!(technology: technology, level: :v1)

      patch_with_required(skills: [])

      expect(response).to have_http_status(:ok)
      expect(profile.student_skills.reload).to be_empty
    end

    it "プログラミング歴を送らなければ、今の内容のまま" do
      profile.student_skills.create!(technology: technology, level: :v1)

      patch_with_required({})

      expect(response).to have_http_status(:ok)
      expect(profile.student_skills.reload.map(&:technology_id)).to eq([ technology.id ])
    end

    it "「その他」の行は、何行でも保存できる（技術が空の行は、同じ技術の重複の対象外）" do
      patch_with_required(skills: [ other_skill("Elm"), other_skill("Haskell") ])

      expect(response).to have_http_status(:ok)
      expect(profile.student_skills.reload.map(&:other_name)).to eq(%w[Elm Haskell])
    end

    it "開始時期と卒業年度は、範囲の制限なく保存できる（権限_バリデーション.md の 17-3-4）" do
      patch_with_required(available_from: "2020-04-01", graduation_year: 2000)
      expect(response).to have_http_status(:ok)

      patch_with_required(available_from: "2040-01-01", graduation_year: 2050)
      expect(response).to have_http_status(:ok)
    end

    it "氏名が空欄なら 422。職種も変わらない（先に確かめてから、トランザクションで書き込むため）" do
      profile.interested_job_middle_categories << middle_a

      patch_profile(name: "", activity_status: "skill_up", interested_job_middle_category_ids: [ middle_b.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["name"]).to eq([ "氏名を入力してください" ])
      expect(profile.reload.interested_job_middle_category_ids).to eq([ middle_a.id ])
    end

    it "活動状況が空欄なら 422" do
      patch_profile(name: "テスト 太郎", activity_status: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["activity_status"]).to eq([ "活動状況を入力してください" ])
    end

    describe "プログラミング歴の行の誤り（API設計.md の 16-3 ⑯）" do
      it "行ごとの誤りは、行の番号を付けた名前で返す（2行目の年数が 51）" do
        patch_with_required(skills: [
          other_skill("Elm"),
          { technology_id: technology.id, other_name: nil, years: 51, level: "v1" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        errors = response.parsed_body["errors"]
        expect(errors["skills[1].years"]).to eq([ "年数は50以下の値にしてください" ])
        expect(errors).not_to have_key("skills[0].years")
      end

      it "年数が 0.5刻みでなければ 422" do
        patch_with_required(skills: [ { technology_id: technology.id, other_name: nil, years: 1.3, level: "v1" } ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["skills[0].years"]).to eq([ "年数は0.5刻みで入力してください" ])
      end

      it "技術も「その他」の名前もなく、レベルもなければ 422" do
        patch_with_required(skills: [ { technology_id: nil, other_name: "", years: nil, level: "" } ])

        expect(response).to have_http_status(:unprocessable_content)
        errors = response.parsed_body["errors"]
        expect(errors["skills[0].technology_id"]).to eq([ "技術を入力してください" ])
        expect(errors["skills[0].level"]).to eq([ "レベルを入力してください" ])
      end

      it "同じ技術が2行あれば、欄全体の誤りとして 422" do
        patch_with_required(skills: [
          { technology_id: technology.id, other_name: nil, years: nil, level: "v1" },
          { technology_id: technology.id, other_name: nil, years: nil, level: "v2" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["skills"]).to eq([ "プログラミング歴に同じ値が重複しています" ])
      end

      it "51行あれば 422（50件まで）" do
        patch_with_required(skills: Array.new(51) { |index| other_skill("言語#{index}") })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["skills"]).to eq([ "プログラミング歴は50件までにしてください" ])
      end
    end

    it "学科が、選んだ学部のものでなければ 422" do
      other_faculty = create(:faculty)

      patch_with_required(faculty_id: other_faculty.id, department_id: department.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["department_id"]).to eq([ "学科は、選んだ学部の中から選んでください" ])
    end

    it "一覧の大学と大学名（その他）の両方があれば 422" do
      patch_with_required(university_id: university.id, university_other_name: "海外の大学")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["university_other_name"]).to eq([ "大学名は入力しないでください" ])
    end

    it "大学名（その他）だけなら保存できる（一覧にない大学）" do
      patch_with_required(university_id: nil, university_other_name: "海外の大学")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["university_other_name"]).to eq("海外の大学")
    end

    it "開始時期が月の1日でなければ 422" do
      patch_with_required(available_from: "2026-11-15")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("available_from")
    end

    it "存在しない大学・職種の番号なら、404 ではなく 422" do
      patch_with_required(university_id: 0, interested_job_middle_category_ids: [ 0 ])

      expect(response).to have_http_status(:unprocessable_content)
      errors = response.parsed_body["errors"]
      expect(errors["university_id"]).to eq([ "大学は一覧にありません" ])
      expect(errors["interested_job_middle_category_ids"]).to eq([ "興味のある職種に選べない値が含まれています" ])
    end

    it "稼働条件の数値が選択肢にない値なら 422" do
      patch_with_required(work_days_per_week: 7)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("work_days_per_week")
    end

    # 順9 で足した、働き方の好み（性格）の5軸
    describe "働き方の好み" do
      it "5つを保存でき、返事にも入る" do
        patch_with_required(
          personality_pace: -2, personality_novelty: -1, personality_collaboration: 0,
          personality_decision: 1, personality_atmosphere: 2
        )

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.values_at(
          "personality_pace", "personality_novelty", "personality_collaboration",
          "personality_decision", "personality_atmosphere"
        )).to eq([ -2, -1, 0, 1, 2 ])
        expect(profile.reload.personality_atmosphere).to eq(2)
      end

      it "範囲の外（3）なら 422" do
        patch_with_required(personality_pace: 3)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["personality_pace"]).to eq([ "働き方の好み（進め方）は2以下の値にしてください" ])
        expect(profile.reload.personality_pace).to eq(0)
      end
    end
  end
end
