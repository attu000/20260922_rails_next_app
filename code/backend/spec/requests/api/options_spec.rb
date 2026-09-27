require "rails_helper"

# ⑦ GET /api/options（選択肢とマスタ）のテスト。
# 詳しくは design/designs/API設計.md の 16-1-9、16-3 ⑦
RSpec.describe "選択肢とマスタ（GET /api/options）", type: :request do
  before do
    # 表示順どおりに並ぶかを見るため、表示順の大きいほうを先に作る
    create(:industry, name: "業界B", position: 2)
    create(:industry, name: "業界A", position: 1)
    create(:business_type, name: "自社サービス", position: 1)
  end

  it "ログインしていなくても 200 で返す" do
    get "/api/options"

    expect(response).to have_http_status(:ok)
  end

  it "人数の選択肢を、名前と日本語の表示名で返す" do
    get "/api/options"

    employee_sizes = response.parsed_body["enums"]["employee_size"]
    expect(employee_sizes.size).to eq(6)
    expect(employee_sizes.first).to eq("value" => "size_1_9", "label" => "1〜9人")
  end

  it "業界・事業形態を表示順で返す" do
    get "/api/options"

    masters = response.parsed_body["masters"]
    expect(masters["industries"].map { |industry| industry["name"] }).to eq(%w[業界A 業界B])
    expect(masters["business_types"].map { |business_type| business_type["name"] }).to eq(%w[自社サービス])
  end

  # 順2（募集の作成・編集）で足した選択肢とマスタ
  describe "募集で使う選択肢とマスタ" do
    before do
      # 表示順どおりに並ぶかを見るため、表示順の大きいほうを先に作る
      major_b = create(:job_major_category, name: "大分類B", position: 2)
      major_a = create(:job_major_category, name: "大分類A", position: 1)
      create(:job_middle_category, job_major_category: major_a, name: "中分類A2", position: 2)
      create(:job_middle_category, job_major_category: major_a, name: "中分類A1", position: 1)
      create(:job_middle_category, job_major_category: major_b, name: "中分類B1", position: 1)
      create(:technology, name: "技術B", category: :language, position: 2)
      create(:technology, name: "技術A", category: :framework, position: 1)
      # 都道府県は表示順の列を持たず、番号の順に並ぶ
      create(:prefecture, id: 13, name: "東京都")
      create(:prefecture, id: 1, name: "北海道")
    end

    it "募集状態・勤務形態・技術の区分の選択肢を、名前と日本語の表示名で返す" do
      get "/api/options"

      enums = response.parsed_body["enums"]
      expect(enums["job_posting_status"]).to eq([
        { "value" => "unpublished", "label" => "非公開" },
        { "value" => "published", "label" => "掲載中" },
        { "value" => "closed", "label" => "終了" }
      ])
      expect(enums["work_style"].map { |option| option["label"] }).to eq(%w[フルリモート 一部リモート 出社])
      expect(enums["technology_category"].map { |option| option["label"] }).to eq(%w[言語 フレームワーク クラウド その他])
    end

    it "稼働条件の数値の選択肢を返す" do
      get "/api/options"

      expect(response.parsed_body["work_conditions"]).to eq(
        "work_days_per_week" => [ 1, 2, 3, 4, 5 ],
        "work_hours_per_day" => [ 2, 3, 4, 5, 6, 8 ],
        "duration_months" => [ 1, 3, 6, 9, 12 ]
      )
    end

    it "職種を、大分類の中に中分類を入れた形で、どちらも表示順で返す" do
      get "/api/options"

      majors = response.parsed_body["masters"]["job_major_categories"]
      expect(majors.map { |major| major["name"] }).to eq(%w[大分類A 大分類B])
      expect(majors.first.keys).to contain_exactly("id", "code", "name", "description", "job_middle_categories")
      expect(majors.first["job_middle_categories"].map { |middle| middle["name"] }).to eq(%w[中分類A1 中分類A2])
      expect(majors.second["job_middle_categories"].map { |middle| middle["name"] }).to eq(%w[中分類B1])
    end

    it "技術を表示順で、都道府県を番号の順で返す" do
      get "/api/options"

      masters = response.parsed_body["masters"]
      expect(masters["technologies"]).to eq([
        { "id" => Technology.find_by!(name: "技術A").id, "name" => "技術A", "category" => "framework" },
        { "id" => Technology.find_by!(name: "技術B").id, "name" => "技術B", "category" => "language" }
      ])
      expect(masters["prefectures"]).to eq([
        { "id" => 1, "name" => "北海道" },
        { "id" => 13, "name" => "東京都" }
      ])
    end
  end

  # 順3（学生プロフィール）で足した選択肢とマスタ
  describe "学生プロフィールで使う選択肢とマスタ" do
    before do
      # 並び順どおりに並ぶかを見るため、後に並ぶほうを先に作る
      create(:university, school_code: "F113310103581", name: "早稲田大学")
      create(:university, school_code: "F101110100010", name: "北海道大学")
      faculty_b = create(:faculty, name: "学部B", position: 2)
      faculty_a = create(:faculty, name: "学部A", position: 1)
      create(:department, faculty: faculty_a, name: "学科A2", position: 2)
      create(:department, faculty: faculty_a, name: "学科A1", position: 1)
      create(:department, faculty: faculty_b, name: "学科B1", position: 1)
    end

    it "学年・活動状況・プログラミング歴のレベルの選択肢を、名前と日本語の表示名で返す" do
      get "/api/options"

      enums = response.parsed_body["enums"]
      expect(enums["grade"].size).to eq(10)
      expect(enums["grade"].first).to eq("value" => "undergrad_1", "label" => "学部1年")
      expect(enums["activity_status"].map { |option| option["label"] }).to eq(%w[今は探していない スキルアップ目的 就活目的])
      expect(enums["skill_level"].first).to eq("value" => "v1", "label" => "v1 学習中")
      expect(enums["skill_level"].size).to eq(4)
    end

    it "大学を学校コードの順で、学部を表示順で返す。学部の中の学科も表示順" do
      get "/api/options"

      masters = response.parsed_body["masters"]
      expect(masters["universities"].map { |university| university["name"] }).to eq(%w[北海道大学 早稲田大学])
      expect(masters["universities"].first.keys).to contain_exactly("id", "name")
      faculties = masters["faculties"]
      expect(faculties.map { |faculty| faculty["name"] }).to eq(%w[学部A 学部B])
      expect(faculties.first.keys).to contain_exactly("id", "name", "departments")
      expect(faculties.first["departments"].map { |department| department["name"] }).to eq(%w[学科A1 学科A2])
      expect(faculties.second["departments"].map { |department| department["name"] }).to eq(%w[学科B1])
    end
  end

  # 順9（性格・カルチャー・工程の入力）で足した選択肢
  describe "性格・カルチャーの5軸と工程" do
    it "5軸を決めた順で、名前と両端の短い名前・説明とともに返す" do
      get "/api/options"

      axes = response.parsed_body["culture_axes"]
      expect(axes.map { |axis| axis["key"] }).to eq(%w[pace novelty collaboration decision atmosphere])
      expect(axes.first).to eq(
        "key" => "pace",
        "name" => "進め方",
        "left_label" => "スピード",
        "left_description" => "まず動くものを作って見せ、直しながら進める",
        "right_label" => "緻密さ",
        "right_description" => "仕様や設計を固めてから作り始める"
      )
    end

    it "工程を表示順で、番号・名前・planning の3つだけ返す（共通段階と大分類の対応は返さない。PR239・PR240）" do
      implementation = create(:work_process, name: "実装", planning: false, position: 2)
      design = create(:work_process, name: "設計", planning: true, position: 1)

      get "/api/options"

      expect(response.parsed_body["masters"]["work_processes"]).to eq([
        { "id" => design.id, "name" => "設計", "planning" => true },
        { "id" => implementation.id, "name" => "実装", "planning" => false }
      ])
    end
  end

  # 順5（応募 → 企業がマッチ）で足した選択肢
  describe "応募で使う選択肢" do
    it "応募理由の12個を、画面に出す順（番号の順ではない）で返す" do
      get "/api/options"

      reasons = response.parsed_body["enums"]["candidacy_reason"]
      expect(reasons.map { |option| option["value"] }).to eq(%w[
        business industry job_major_category job_middle_category business_type work_process
        internship_details growth culture hourly_wage work_conditions technologies
      ])
      expect(reasons.first).to eq("value" => "business", "label" => "事業内容")
    end

    it "学生から見た状態の4つを、名前と日本語の表示名で返す" do
      get "/api/options"

      expect(response.parsed_body["enums"]["my_status"]).to eq([
        { "value" => "none", "label" => "関係なし" },
        { "value" => "applied", "label" => "応募済み" },
        { "value" => "scouted", "label" => "スカウトあり" },
        { "value" => "matched", "label" => "マッチ済み" }
      ])
    end

    it "企業から見たタグの6つを、名前と日本語の表示名で返す" do
      get "/api/options"

      expect(response.parsed_body["enums"]["candidacy_tag"]).to eq([
        { "value" => "pending_application", "label" => "未対応応募" },
        { "value" => "scouted", "label" => "スカウト済み" },
        { "value" => "matched", "label" => "マッチ" },
        { "value" => "declined", "label" => "見送り" },
        { "value" => "passed", "label" => "合格" },
        { "value" => "failed", "label" => "不合格" }
      ])
    end
  end
end
