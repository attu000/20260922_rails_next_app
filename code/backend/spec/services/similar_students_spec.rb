require "rails_helper"

# 似た学生を選ぶ部品（app/services/similar_students.rb）のテスト。
# 詳しくは design/designs/処理設計_類似度.md の 7-3「ポップアップ・通知の取り方」、API設計.md の 16-3 ㉕。
# 応募がない（行動の近さの重みが0）ので、近さ f は内容の近さだけになる。
# Ruby を持つ学生どうしは 0.30（技術）+ 0.10（カルチャー。5軸すべて中央で一致）= 0.40、それ以外は 0.10
RSpec.describe SimilarStudents do
  let(:company) { create(:company_user).company_profile }
  let(:ruby) { create(:technology) }
  # 稼働条件は「週3日以上」だけ。週3日以上働ける学生が合う
  let(:job_posting) { create(:job_posting, :published, company_profile: company, min_work_days_per_week: 3) }
  let(:student) { create_student.tap { |s| add_skill(s, ruby) } }

  def create_student(last_active_on: Time.zone.today, **attributes)
    student = create(:student_user, last_active_on: last_active_on).student_profile
    student.update!(attributes) if attributes.any?
    student
  end

  def add_skill(student, technology)
    StudentSkill.create!(student_profile: student, technology: technology, level: :v1)
  end

  # 学生・募集をすべて作ってから、推薦の集計（項目数）を作り直して選ぶ
  def similar_ids
    student
    job_posting
    RecommendationStatsRebuildJob.perform_now
    described_class.ids(student, job_posting)
  end

  it "稼働条件に合う学生が先。f が低くても、合わない学生より前に来る。合う学生が5人に満たなければ、合わない学生が f の高い順に続く" do
    matched_near = create_student(work_days_per_week: 3).tap { |s| add_skill(s, ruby) }
    matched_far = create_student(work_days_per_week: 5)
    unmatched_near = create_student(work_days_per_week: 2).tap { |s| add_skill(s, ruby) }
    unmatched_far = create_student

    expect(similar_ids).to eq([ matched_near.id, matched_far.id, unmatched_near.id, unmatched_far.id ])
  end

  it "本人、30日より前に活動した学生、その募集とやりとりがある学生は出さない。ほかの募集とだけやりとりがある学生は出す。足りなければある分だけ" do
    create_student(last_active_on: Time.zone.today - 31)
    create(:candidacy, job_posting: job_posting, student_profile: create_student)
    create(:candidacy, :scout, job_posting: job_posting, student_profile: create_student)
    other_posting_only = create_student.tap do |s|
      create(:candidacy, job_posting: create(:job_posting, :published, company_profile: company), student_profile: s)
    end
    no_candidacy = create_student

    expect(similar_ids).to contain_exactly(other_posting_only.id, no_candidacy.id)
  end

  it "最大5人。f が同じなら、最終活動が新しい順 → 番号の大きい順（PR317）" do
    day3 = create_student(last_active_on: Time.zone.today - 3)
    day1_first = create_student(last_active_on: Time.zone.today - 1)
    day1_second = create_student(last_active_on: Time.zone.today - 1)
    day2 = create_student(last_active_on: Time.zone.today - 2)
    day4 = create_student(last_active_on: Time.zone.today - 4)
    create_student(last_active_on: Time.zone.today - 5)

    expect(similar_ids).to eq([ day1_second.id, day1_first.id, day2.id, day3.id, day4.id ])
  end
end
