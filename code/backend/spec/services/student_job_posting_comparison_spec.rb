require "rails_helper"

# 学生と募集の比較（app/services/student_job_posting_comparison.rb）のテスト。
# 業界・職種・使用技術の重なりと、稼働条件6項目の一致・不一致・未入力。
# 詳しくは design/designs/API設計.md の 16-3 ㉓、その他決め事.md の 5-6・5-10
RSpec.describe StudentJobPostingComparison do
  let(:student) { create(:student_user).student_profile }
  let(:job_posting) { create(:job_posting) }

  # 比べた結果。reload で読み込み済みの関連を捨て、テストで足した行を読み直させる
  def comparison
    described_class.new(student: student.reload, job_posting: job_posting.reload).result
  end

  # 稼働条件の1項目の結果
  def work_condition(item)
    comparison[:work_conditions].find { |row| row[:item] == item }[:result]
  end

  it "稼働条件は、決めた6項目をこの順で返す" do
    expect(comparison[:work_conditions].map { |row| row[:item] }).to eq(
      %w[work_days_per_week work_hours_per_day duration_months start_month work_style work_location]
    )
  end

  describe "業界" do
    let(:industries) { create_list(:industry, 3) }

    it "両方にある業界の番号を返す" do
      student.interested_industries << industries[0] << industries[1]
      job_posting.industries << industries[1] << industries[2]

      expect(comparison[:industry_ids]).to eq(matched: [ industries[1].id ])
    end

    it "両方入っていて重なりがなければ、空の配列" do
      student.interested_industries << industries[0]
      job_posting.industries << industries[1]

      expect(comparison[:industry_ids]).to eq(matched: [])
    end

    it "どちらかが空なら nil（未入力）" do
      job_posting.industries << industries[0]

      expect(comparison[:industry_ids]).to be_nil
    end
  end

  describe "職種" do
    let(:middle_categories) { create_list(:job_middle_category, 2) }

    it "募集のサブの職種でも一致になる" do
      student.interested_job_middle_categories << middle_categories[1]
      job_posting.job_posting_job_categories.create!(job_middle_category: middle_categories[0], role: :main)
      job_posting.job_posting_job_categories.create!(job_middle_category: middle_categories[1], role: :related)

      expect(comparison[:job_middle_category_ids]).to eq(matched: [ middle_categories[1].id ])
    end

    it "募集の職種が空なら nil（未入力）" do
      student.interested_job_middle_categories << middle_categories[0]

      expect(comparison[:job_middle_category_ids]).to be_nil
    end
  end

  describe "使用技術" do
    let(:technology) { create(:technology) }

    it "プログラミング歴の技術と、募集の使用技術の重なりを返す" do
      student.student_skills.create!(technology: technology, level: :v2)
      job_posting.technologies << technology

      expect(comparison[:technology_ids]).to eq(matched: [ technology.id ])
    end

    it "プログラミング歴の「その他」の行は比べない（その行だけなら未入力）" do
      student.student_skills.create!(other_name: "Elm", level: :v1)
      job_posting.technologies << technology

      expect(comparison[:technology_ids]).to be_nil
    end
  end

  describe "数の項目（週の日数・1日の時間・継続期間）" do
    it "学生の上限が募集の下限より多い・同じなら一致、少なければ不一致" do
      student.update!(work_days_per_week: 3, work_hours_per_day: 4, duration_months: 3)
      job_posting.update!(min_work_days_per_week: 2, min_work_hours_per_day: 4, min_duration_months: 6)

      expect(work_condition("work_days_per_week")).to eq("match")
      expect(work_condition("work_hours_per_day")).to eq("match")
      expect(work_condition("duration_months")).to eq("mismatch")
    end

    it "どちらかが空なら未入力" do
      student.update!(work_days_per_week: 3)
      job_posting.update!(min_work_hours_per_day: 4)

      expect(work_condition("work_days_per_week")).to eq("not_judged")
      expect(work_condition("work_hours_per_day")).to eq("not_judged")
      expect(work_condition("duration_months")).to eq("not_judged")
    end
  end

  describe "開始時期" do
    let(:this_month) { Time.zone.today.beginning_of_month }

    it "募集が随時（空欄）なら、学生が空でも一致" do
      expect(work_condition("start_month")).to eq("match")
    end

    it "募集の開始月が今月より前なら、学生が空でも一致（すでに始まっている仕事）" do
      job_posting.update!(start_month: this_month.prev_month)

      expect(work_condition("start_month")).to eq("match")
    end

    it "募集の開始月が今月以降で、学生が空なら未入力" do
      job_posting.update!(start_month: this_month.next_month)

      expect(work_condition("start_month")).to eq("not_judged")
    end

    it "学生がその月までに働き始められれば一致、遅ければ不一致" do
      job_posting.update!(start_month: this_month.next_month)

      student.update!(available_from: this_month.next_month)
      expect(work_condition("start_month")).to eq("match")

      student.update!(available_from: this_month.next_month(2))
      expect(work_condition("start_month")).to eq("mismatch")
    end
  end

  describe "勤務形態" do
    it "募集の勤務形態を、学生が可能にしていれば一致、不可なら不一致" do
      job_posting.update!(work_style: :onsite)

      expect(work_condition("work_style")).to eq("match")

      student.update!(can_onsite: false)
      expect(work_condition("work_style")).to eq("mismatch")
    end

    it "募集の勤務形態が空なら未入力" do
      expect(work_condition("work_style")).to eq("not_judged")
    end
  end

  describe "勤務地" do
    let(:tokyo) { create(:prefecture) }
    let(:osaka) { create(:prefecture) }

    it "フルリモートなら、学生の出社できる都道府県が空でも一致（勤務地を問わない）" do
      job_posting.update!(work_style: :full_remote)

      expect(work_condition("work_location")).to eq("match")
    end

    it "募集の都道府県が、学生の出社できる都道府県にあれば一致、なければ不一致" do
      job_posting.update!(work_style: :onsite, prefecture: tokyo)

      student.commutable_prefectures << tokyo
      expect(work_condition("work_location")).to eq("match")

      student.update!(commutable_prefecture_ids: [ osaka.id ])
      expect(work_condition("work_location")).to eq("mismatch")
    end

    it "学生の出社できる都道府県が空なら、不一致ではなく未入力（PR257）" do
      job_posting.update!(work_style: :onsite, prefecture: tokyo)

      expect(work_condition("work_location")).to eq("not_judged")
    end

    it "フルリモートでなく、募集の都道府県が空なら未入力" do
      job_posting.update!(work_style: :partial_remote)
      student.commutable_prefectures << tokyo

      expect(work_condition("work_location")).to eq("not_judged")
    end
  end
end
