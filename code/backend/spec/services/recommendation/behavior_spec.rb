require "rails_helper"

# 行動の近さ（共起と CF）のテスト（design/designs/処理設計_類似度.md の 7-2）。期待値は手で計算したもの。
# 例は順12 の推薦の集計のテストと同じで、応募理由と日時を付けた
RSpec.describe Recommendation::Behavior do
  def create_student
    create(:student_user).student_profile
  end

  # 応募理由を付けた応募
  def apply(student, posting, reasons)
    candidacy = create(:candidacy, student_profile: student, job_posting: posting)
    candidacy.save_reasons!(reasons)
    candidacy
  end

  # 田中：P1（事業内容・カルチャー。4日前）、P2（事業内容。見送られた。今日）に応募
  # 佐藤：P1（事業内容。3日前）に応募、P2 からスカウト（まだ応じていない）
  # 鈴木：P1 のスカウトに今日マッチ（カルチャー）
  # → P1 に興味を示したのは3人（新しい順に 鈴木・佐藤・田中）、P2 は田中だけ。P3 はやりとりなし
  let(:p1) { create(:job_posting, :published) }
  let(:p2) { create(:job_posting, :published) }
  let(:p3) { create(:job_posting, :published) }
  let(:tanaka) { create_student }
  let(:sato) { create_student }
  let(:suzuki) { create_student }

  before do
    apply(tanaka, p1, %w[business culture]).update_columns(created_at: 4.days.ago)
    apply(tanaka, p2, %w[business]).update!(status: :declined)
    apply(sato, p1, %w[business]).update_columns(created_at: 3.days.ago)
    create(:candidacy, :scout, student_profile: sato, job_posting: p2)
    create(:candidacy, :scout, student_profile: suzuki, job_posting: p1).match_by_student(%w[culture])
    p3
    # 件数と self_weight（順12）を数えておく
    RecommendationStatsRebuildJob.perform_now
  end

  # 手計算に使う値
  let(:u_tanaka) { 1 / Math.log(3) } # 田中の件数2
  let(:u_single_student) { 1 / Math.log(2) } # 佐藤・鈴木の件数1
  let(:u_p1) { 1 / Math.log(4) } # P1 の人数3
  let(:u_p2) { 1 / Math.log(2) } # P2 の人数1

  describe ".posting_posting（募集どうし）" do
    it "P1 と P2 の両方に興味を示したのは田中だけなので、共起は u(田中)。CF は √(W(P1) × W(P2)) で割る" do
      row = described_class.posting_posting([ p1.id ], [ p2.id ]).sole

      w_p1 = u_tanaka + 2 * u_single_student
      w_p2 = u_tanaka
      expect(row).to have_attributes(left_id: p1.id, right_id: p2.id)
      expect(row.co).to be_within(1e-9).of(u_tanaka)
      expect(row.cf).to be_within(1e-9).of(u_tanaka / Math.sqrt(w_p1 * w_p2))
    end

    it "共起がない組（やりとりのない P3）は返さない" do
      rows = described_class.posting_posting([ p1.id ], [ p2.id, p3.id ])

      expect(rows.map(&:right_id)).to eq([ p2.id ])
    end

    it "自分自身との組は、共起が self_weight と同じになり、CF は1" do
      row = described_class.posting_posting([ p1.id ], [ p1.id ]).sole

      expect(row.cf).to be_within(1e-9).of(1.0)
    end

    it "上限を1人にすると、P1 のいちばん新しい興味（鈴木）だけをたどるので、P2 との共起は出ない" do
      stub_const("Recommendation::Parameters::INTERESTS_PER_POSTING", 1)

      expect(described_class.posting_posting([ p1.id ], [ p2.id ])).to eq([])
    end
  end

  describe ".student_student（学生どうし）" do
    it "田中と佐藤は P1 が共通。理由は「事業内容・カルチャー」と「事業内容」で、g = 0.5 + 0.5 × 1/2 = 0.75" do
      row = described_class.student_student([ tanaka.id ], [ sato.id ]).sole

      co = u_p1 * 0.75
      w_tanaka = u_p1 + u_p2
      w_sato = u_p1
      expect(row.co).to be_within(1e-9).of(co)
      expect(row.cf).to be_within(1e-9).of(co / Math.sqrt(w_tanaka * w_sato))
    end

    it "佐藤と鈴木は理由が1つも一致しない（事業内容とカルチャー）ので、g は基礎点の 0.5" do
      row = described_class.student_student([ sato.id ], [ suzuki.id ]).sole

      expect(row.co).to be_within(1e-9).of(u_p1 * 0.5)
    end

    it "1対多で、共起のある相手の分だけ返す" do
      rows = described_class.student_student([ tanaka.id ], [ sato.id, suzuki.id ])

      expect(rows.to_h { |row| [ row.right_id, row.co ] }).to match(
        sato.id => be_within(1e-9).of(u_p1 * 0.75),
        suzuki.id => be_within(1e-9).of(u_p1 * 0.75)
      )
    end

    it "上限を1件にすると、田中のいちばん新しい興味（P2）だけをたどるので、佐藤との共起は出ない" do
      stub_const("Recommendation::Parameters::INTERESTS_PER_STUDENT", 1)

      expect(described_class.student_student([ tanaka.id ], [ sato.id ])).to eq([])
    end
  end

  it "ジョブが数え直す前で件数が0のままでも、0で割らずに件数1として数える" do
    tanaka.recommendation_stat.update_columns(interest_count: 0)

    row = described_class.posting_posting([ p1.id ], [ p2.id ]).sole

    expect(row.co).to be_within(1e-9).of(1 / Math.log(2))
  end
end
