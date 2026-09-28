require "rails_helper"

# 応募・マッチのあとのジョブのテスト（処理設計_類似度.md の 7-5「応募・マッチ時の手順」）。
# ジョブを実際に動かし（perform_now）、数え直す範囲と値を確かめる。
# 例は推薦の集計のテスト（spec/models/*_recommendation_stat_spec.rb）と同じ
RSpec.describe InterestRecordedJob, type: :job do
  def create_student
    create(:student_user).student_profile
  end

  # 応募理由を付けた応募（興味として数える）
  def apply(student, posting)
    candidacy = create(:candidacy, student_profile: student, job_posting: posting)
    candidacy.save_reasons!(%w[business])
    candidacy
  end

  # 田中：P1・P2 に応募（P2 は見送られた）／佐藤：P1 に応募、P2 からスカウト（まだ応じていない）／鈴木：P1 のスカウトにマッチ
  let(:p1) { create(:job_posting, :published) }
  let(:p2) { create(:job_posting, :published) }
  let(:p3) { create(:job_posting, :published) }
  let(:tanaka) { create_student }
  let(:sato) { create_student }
  let(:suzuki) { create_student }
  let!(:sato_scout) { create(:candidacy, :scout, student_profile: sato, job_posting: p2) }

  before do
    apply(tanaka, p1)
    apply(tanaka, p2).update!(status: :declined)
    apply(sato, p1)
    create(:candidacy, :scout, student_profile: suzuki, job_posting: p1).match_by_student(%w[culture])
    apply(tanaka, p3)
  end

  it "推薦用の待ち行列（recommendation）に入る" do
    expect(described_class.new.queue_name).to eq("recommendation")
  end

  it "佐藤が P2 にマッチしたあと、P2 に興味を示した学生（田中・佐藤）と、佐藤が興味を示した募集（P1・P2）を数え直す" do
    sato_scout.match_by_student(%w[technologies])

    described_class.perform_now(sato_scout)

    # 田中：u(P1) + u(P2) + u(P3) = 1/log(4) + 1/log(3) + 1/log(2)（P2 の人数が2になった）
    expect(tanaka.reload.recommendation_stat).to have_attributes(interest_count: 3)
    expect(tanaka.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3) + 1 / Math.log(2))
    # 佐藤：件数2、u(P1) + u(P2) = 1/log(4) + 1/log(3)
    expect(sato.reload.recommendation_stat).to have_attributes(interest_count: 2)
    expect(sato.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3))
    # P1：新しい興味はないが、u(佐藤) が下がるので数え直す。u(田中) + u(佐藤) + u(鈴木) = 1/log(4) + 1/log(3) + 1/log(2)
    expect(p1.reload.recommendation_stat).to have_attributes(interest_count: 3)
    expect(p1.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3) + 1 / Math.log(2))
    # P2：u(田中) + u(佐藤) = 1/log(4) + 1/log(3)
    expect(p2.reload.recommendation_stat).to have_attributes(interest_count: 2)
    expect(p2.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3))
  end

  it "範囲の外の学生（鈴木）と募集（P3）は数え直さない" do
    sato_scout.match_by_student(%w[technologies])

    described_class.perform_now(sato_scout)

    # 仮の値の行を作っていないので、数え直していなければ行がないまま
    expect(suzuki.reload.recommendation_stat).to be_nil
    expect(p3.reload.recommendation_stat).to be_nil
  end

  it "数え直しのあとに、似た募集を持つ他社へ通知を作る。応募・マッチした募集の会社と、やりとりがある募集の会社には送らない" do
    # 近さの計算に使う集計の行（項目数）を、全募集・全学生について作っておく
    RecommendationStatsRebuildJob.perform_now
    sato_scout.match_by_student(%w[technologies])

    described_class.perform_now(sato_scout)

    # 佐藤は P1 に応募、P2 にマッチしたので、残る P3 の会社にだけ届く
    expect(Notification.pluck(:user_id, :student_profile_id)).to eq([ [ p3.company_profile.user_id, sato.id ] ])
  end

  it "2回実行しても、同じ値になる" do
    sato_scout.match_by_student(%w[technologies])

    2.times { described_class.perform_now(sato_scout) }

    expect(sato.reload.recommendation_stat).to have_attributes(interest_count: 2)
    expect(sato.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3))
  end
end
