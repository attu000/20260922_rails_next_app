require "rails_helper"

# 似た募集を選ぶ部品（app/services/similar_job_postings.rb）のテスト。
# 詳しくは design/designs/処理設計_類似度.md の 7-3「ポップアップ・通知の取り方」、API設計.md の 16-3 ㉝。
# 応募がない（行動の近さの重みが0）ので、近さ f は内容の近さだけになる。
# Ruby を使う募集どうしは 0.25（技術）+ 0.10（カルチャー。5軸すべて中央で一致）= 0.35、それ以外は 0.10
RSpec.describe SimilarJobPostings do
  let(:company) { create(:company_user).company_profile }
  let(:ruby) { create(:technology) }
  # 稼働条件は「週3日まで」だけ。週3日以下で働ける募集が合う
  let(:student) { create(:student_user).student_profile.tap { |s| s.update!(work_days_per_week: 3) } }
  let(:job_posting) { create_posting(technology_ids: [ ruby.id ]) }

  def create_posting(technology_ids: [], **attributes)
    create(:job_posting, :published, company_profile: company, **attributes).tap do |posting|
      posting.save_posting(technology_ids: technology_ids) if technology_ids.any?
    end
  end

  # 学生・募集をすべて作ってから、推薦の集計（項目数）を作り直して選ぶ
  def similar_ids
    student
    job_posting
    RecommendationStatsRebuildJob.perform_now
    described_class.ids(job_posting, student)
  end

  it "稼働条件に合う募集が先。f が低くても、合わない募集より前に来る。合う募集が5件に満たなければ、合わない募集が f の高い順に続く" do
    matched_near = create_posting(min_work_days_per_week: 3, technology_ids: [ ruby.id ])
    matched_far = create_posting(min_work_days_per_week: 2)
    unmatched_near = create_posting(min_work_days_per_week: 5, technology_ids: [ ruby.id ])
    unmatched_far = create_posting

    expect(similar_ids).to eq([ matched_near.id, matched_far.id, unmatched_near.id, unmatched_far.id ])
  end

  it "その募集自身、掲載中でない募集、自分とやりとりがある募集は出さない。ほかの学生だけがやりとりしている募集は出す。足りなければある分だけ" do
    create(:job_posting, company_profile: company)
    create(:job_posting, :closed, company_profile: company)
    create(:candidacy, job_posting: create_posting, student_profile: student)
    create(:candidacy, :scout, job_posting: create_posting, student_profile: student)
    applied_by_other = create_posting.tap { |posting| create(:candidacy, job_posting: posting) }
    no_candidacy = create_posting

    expect(similar_ids).to contain_exactly(applied_by_other.id, no_candidacy.id)
  end

  it "最大5件。f が同じなら、新着順（最初に掲載した日時の新しい順）→ 番号の大きい順（PR317）" do
    published_at = ->(days_ago) { Time.current.beginning_of_day - days_ago.days }
    day3 = create_posting.tap { |p| p.update_columns(published_at: published_at.(3)) }
    day1_first = create_posting.tap { |p| p.update_columns(published_at: published_at.(1)) }
    day1_second = create_posting.tap { |p| p.update_columns(published_at: published_at.(1)) }
    day2 = create_posting.tap { |p| p.update_columns(published_at: published_at.(2)) }
    day4 = create_posting.tap { |p| p.update_columns(published_at: published_at.(4)) }
    create_posting.tap { |p| p.update_columns(published_at: published_at.(5)) }

    expect(similar_ids).to eq([ day1_second.id, day1_first.id, day2.id, day3.id, day4.id ])
  end
end
