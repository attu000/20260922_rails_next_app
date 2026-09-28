require "rails_helper"

# 推薦の集計の全体の作り直しのテスト（処理設計_類似度.md の 7-5「全体の作り直し」）。
# 行がない・古い値が入っている、のどちらからでも、すべての列が元データの値になることを確かめる。
# 例は推薦の集計のテスト（spec/models/*_recommendation_stat_spec.rb）と同じ
RSpec.describe RecommendationStatsRebuildJob, type: :job do
  def create_student
    create(:student_user).student_profile
  end

  # 応募理由を付けた応募（興味として数える）
  def apply(student, posting)
    candidacy = create(:candidacy, student_profile: student, job_posting: posting)
    candidacy.save_reasons!(%w[business])
    candidacy
  end

  # 田中：P1・P2 に応募（P2 は見送られた）／佐藤：P1 に応募、P2 からスカウト（まだ応じていない）／鈴木：P1 のスカウトにマッチ／
  # 高橋：何もしていない。P3 はやりとりなし
  let(:p1) { create(:job_posting, :published) }
  let(:p2) { create(:job_posting, :published) }
  let(:p3) { create(:job_posting, :published) }
  let(:tanaka) { create_student }
  let(:sato) { create_student }
  let(:suzuki) { create_student }
  let(:takahashi) { create_student }
  let(:technology) { create(:technology) }

  before do
    apply(tanaka, p1)
    apply(tanaka, p2).update!(status: :declined)
    apply(sato, p1)
    create(:candidacy, :scout, student_profile: sato, job_posting: p2)
    create(:candidacy, :scout, student_profile: suzuki, job_posting: p1).match_by_student(%w[culture])
    takahashi
    p3
    # 項目数：田中は技術1つ（行は save_profile で自動でできる）、P1 は技術1つと業界1つ
    tanaka.save_profile(skills: [ { technology_id: technology.id, level: "v1" } ])
    p1.save_posting(technology_ids: [ technology.id ], industry_ids: [ create(:industry).id ])
    # 古い値を入れておく（不具合で値がずれた状態のつもり）
    tanaka.recommendation_stat.update!(interest_count: 9, self_weight: 9.9, technology_count: 5)
    p1.recommendation_stat.update!(interest_count: 0, self_weight: 0, industry_count: 7)
  end

  it "推薦用の待ち行列（recommendation）に入る" do
    expect(described_class.new.queue_name).to eq("recommendation")
  end

  it "行がない学生・募集には行を作り、全員が1行ずつになる" do
    described_class.perform_now

    expect(StudentRecommendationStat.where(student_profile: [ tanaka, sato, suzuki, takahashi ]).count).to eq(4)
    expect(JobPostingRecommendationStat.where(job_posting: [ p1, p2, p3 ]).count).to eq(3)
    expect(takahashi.reload.recommendation_stat).to have_attributes(interest_count: 0, self_weight: 0, technology_count: 0)
    expect(p3.reload.recommendation_stat).to have_attributes(interest_count: 0, self_weight: 0, technology_count: 0)
  end

  it "古い値が入っていた行も、件数・self_weight・項目数のすべてを元データの値で上書きする" do
    described_class.perform_now

    # 田中：件数2、u(P1) + u(P2) = 1/log(4) + 1/log(2)、技術1つ
    expect(tanaka.reload.recommendation_stat).to have_attributes(interest_count: 2, technology_count: 1)
    expect(tanaka.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(2))
    # P1：件数3、u(田中) + u(佐藤) + u(鈴木) = 1/log(3) + 1/log(2) + 1/log(2)、技術1つ・業界1つ
    expect(p1.reload.recommendation_stat).to have_attributes(interest_count: 3, technology_count: 1, industry_count: 1)
    expect(p1.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(3) + 2 / Math.log(2))
    # 佐藤・P2：まだ応じていないスカウトは数えない
    expect(sato.reload.recommendation_stat.interest_count).to eq(1)
    expect(p2.reload.recommendation_stat.interest_count).to eq(1)
  end

  it "区切り（BATCH_SIZE）をまたいでも、全員を数え直す" do
    # 区切りを2件にして、学生4人・募集3件を複数回に分けて処理させる
    stub_const("#{described_class}::BATCH_SIZE", 2)

    described_class.perform_now

    expect(tanaka.reload.recommendation_stat.interest_count).to eq(2)
    expect(takahashi.reload.recommendation_stat).to be_present
    expect(p1.reload.recommendation_stat.interest_count).to eq(3)
    expect(p3.reload.recommendation_stat).to be_present
  end
end
