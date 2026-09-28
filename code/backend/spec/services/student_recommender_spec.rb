require "rails_helper"

# 学生検索の「○○募集におすすめ順」の選び方のテスト（design/designs/処理設計_類似度.md の 7-5「C5 学生検索」）。
# 候補を内容の経路（上位 N_C 人）と行動の経路（P と行動が近い上位 K_B 件の募集の学生）から集めること、
# 群ごとに上位 R 人を f の高い順に並べることを確かめる。件数のパラメータは、テストの中で小さい数に差し替える
RSpec.describe StudentRecommender do
  let(:ruby) { create(:technology) }
  let(:education) { create(:industry) }
  # 募集 P：技術 Ruby、業界 教育
  let!(:posting) do
    create(:job_posting, :published).tap do |posting|
      posting.save_posting(technology_ids: [ ruby.id ], industry_ids: [ education.id ])
    end
  end

  def create_student(**attributes)
    student = create(:student_user).student_profile
    student.save_profile(attributes)
    student
  end

  def create_posting
    create(:job_posting, :published)
  end

  def apply(student, job_posting)
    create(:candidacy, student_profile: student, job_posting: job_posting).save_reasons!(%w[business])
  end

  def group(*students)
    StudentProfile.where(id: students.map(&:id))
  end

  describe "2つの経路から候補を集める" do
    # 内容の近さ：best 0.70 > middle 0.40 > plain 0.10 > behavior 0.09（働き方の好みが1軸ずれている）
    let!(:best) { create_student(skills: [ { technology_id: ruby.id, level: "v1" } ], interested_industry_ids: [ education.id ]) }
    let!(:middle) { create_student(skills: [ { technology_id: ruby.id, level: "v1" } ]) }
    let!(:plain) { create_student }
    let!(:behavior) { create_student(personality_pace: 2) }
    # P に応募した applicant は、Q にも応募している。behavior は Q に応募している → Q は P と行動が近い
    let!(:applicant) { create_student }
    let!(:q) { create_posting }

    before do
      apply(applicant, posting)
      apply(applicant, q)
      apply(behavior, q)
      RecommendationStatsRebuildJob.perform_now
    end

    it "N_C = 1 なら、内容の経路は best だけ。内容の近さが最も低い behavior も、行動の経路で候補に入る" do
      stub_const("Recommendation::Parameters::CONTENT_ROUTE_SIZE", 1)

      ids = described_class.ranked_ids(posting, [ group(best, middle, plain, behavior) ])

      expect(ids).to contain_exactly(best.id, behavior.id)
    end

    it "どちらの経路にも入らない学生（middle・plain）は返さない。候補は f の高い順に並ぶ" do
      stub_const("Recommendation::Parameters::CONTENT_ROUTE_SIZE", 1)

      ids = described_class.ranked_ids(posting, [ group(best, middle, plain, behavior) ])

      expect(ids.first).to eq(best.id)
    end

    it "N_C が十分大きければ、群の全員が候補になり、内容の近さの順に並ぶ（行動の近さが小さい場合）" do
      ids = described_class.ranked_ids(posting, [ group(best, middle, plain) ])

      expect(ids).to eq([ best.id, middle.id, plain.id ])
    end

    it "群ごとに上位 R 人を返し、合う群のあとに合わない群を続ける" do
      stub_const("Recommendation::Parameters::RERANK_SIZE", 1)

      ids = described_class.ranked_ids(posting, [ group(middle, best), group(plain) ])

      expect(ids).to eq([ best.id, plain.id ])
    end
  end

  it "K_B = 1 なら、P と CF が最も高い募集の学生だけが行動の経路に入る（P 自身は行動の経路の募集に入らない）" do
    # applicant1 は P・Q、applicant2 は P・Q・Q2 に応募。P と Q の共通は2人、Q2 は1人なので、CF は Q の方が高い
    applicant1 = create_student
    applicant2 = create_student
    q = create_posting
    q2 = create_posting
    [ posting, q ].each { |job_posting| apply(applicant1, job_posting) }
    [ posting, q, q2 ].each { |job_posting| apply(applicant2, job_posting) }
    via_q = create_student
    via_q2 = create_student
    apply(via_q, q)
    apply(via_q2, q2)
    RecommendationStatsRebuildJob.perform_now
    stub_const("Recommendation::Parameters::CONTENT_ROUTE_SIZE", 0)
    stub_const("Recommendation::Parameters::BEHAVIOR_ROUTE_POSTINGS", 1)

    ids = described_class.ranked_ids(posting, [ group(via_q, via_q2) ])

    expect(ids).to eq([ via_q.id ])
  end

  it "f が同じなら、最終活動の新しい順" do
    older = create_student
    newer = create_student
    older.user.update!(last_active_on: 3.days.ago.to_date)
    newer.user.update!(last_active_on: 1.day.ago.to_date)
    RecommendationStatsRebuildJob.perform_now

    expect(described_class.ranked_ids(posting, [ group(older, newer) ])).to eq([ newer.id, older.id ])
  end
end
