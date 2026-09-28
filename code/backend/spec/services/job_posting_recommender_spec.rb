require "rails_helper"

# 募集一覧のおすすめ順の選び方のテスト（design/designs/処理設計_類似度.md の 7-5「S2 募集一覧のおすすめ順」）。
# 点の大きさそのものは Recommendation::* のテストで確かめているので、ここでは「どれが選ばれ、どう並ぶか」を見る。
# 上位の件数（R）は、テストの中で小さい数に差し替える
RSpec.describe JobPostingRecommender do
  let(:ruby) { create(:technology) }
  let(:education) { create(:industry) }

  def create_student(**attributes)
    student = create(:student_user).student_profile
    student.save_profile(attributes)
    student
  end

  def create_posting(**attributes)
    posting = create(:job_posting, :published)
    posting.save_posting(attributes)
    posting
  end

  def apply(student, posting)
    create(:candidacy, student_profile: student, job_posting: posting).save_reasons!(%w[business])
  end

  def group(*postings)
    JobPosting.where(id: postings.map(&:id))
  end

  describe "内容の近さで決まる並び（学生に興味の履歴がないとき、f は内容の近さだけ）" do
    # 学生：技術 Ruby、業界 教育。内容の近さは best 0.70 > middle 0.40 > plain 0.10
    let(:student) { create_student(skills: [ { technology_id: ruby.id, level: "v1" } ], interested_industry_ids: [ education.id ]) }
    let!(:best) { create_posting(technology_ids: [ ruby.id ], industry_ids: [ education.id ]) }
    let!(:middle) { create_posting(technology_ids: [ ruby.id ]) }
    let!(:plain) { create_posting }
    let!(:other_group) { create_posting }

    before { RecommendationStatsRebuildJob.perform_now }

    it "群ごとに f の高い順に並べ、合う群のあとに合わない群を続ける" do
      ids = described_class.ranked_ids(student, [ group(plain, best, middle), group(other_group) ])

      expect(ids).to eq([ best.id, middle.id, plain.id, other_group.id ])
    end

    it "上位 R 件だけを返す（R = 2 なら、合う群は best・middle の2件）" do
      stub_const("Recommendation::Parameters::RERANK_SIZE", 2)

      ids = described_class.ranked_ids(student, [ group(plain, best, middle), group(other_group) ])

      expect(ids).to eq([ best.id, middle.id, other_group.id ])
    end
  end

  it "内容の近さが同じなら、学生の興味と行動が近い募集が上に来る" do
    # 学生 S は P_x に応募。T は P_x と near に応募。near と far はどちらもタグなし（内容の近さは同じ 0.10）
    student = create_student
    other = create_student
    p_x = create_posting
    near = create_posting
    far = create_posting
    apply(student, p_x)
    apply(other, p_x)
    apply(other, near)
    RecommendationStatsRebuildJob.perform_now

    expect(described_class.ranked_ids(student, [ group(far, near) ])).to eq([ near.id, far.id ])
  end

  it "f が同じなら新着順（最初に掲載した日時の新しい順）" do
    student = create_student
    older = create_posting
    newer = create_posting
    older.update_columns(published_at: 2.days.ago)
    newer.update_columns(published_at: 1.day.ago)
    RecommendationStatsRebuildJob.perform_now

    expect(described_class.ranked_ids(student, [ group(older, newer) ])).to eq([ newer.id, older.id ])
  end
end
