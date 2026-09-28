require "rails_helper"

# 募集どうし・学生どうしの近さ f のテスト（design/designs/処理設計_類似度.md の 7-2）。
# タグを何も入れない募集・学生を使うので、内容の近さはカルチャー（5軸すべて中央で一致）の 0.10 だけになる。
# そこに行動の近さを、データの量に応じた重みで混ぜた値を、手計算と突き合わせる
RSpec.describe Recommendation::Similarity do
  def create_student
    create(:student_user).student_profile
  end

  def apply(student, posting, reasons)
    candidacy = create(:candidacy, student_profile: student, job_posting: posting)
    candidacy.save_reasons!(reasons)
    candidacy
  end

  # 行動の近さのテストと同じ例に、P4 と、P4 だけに応募した高橋を足した
  let(:p1) { create(:job_posting, :published) }
  let(:p2) { create(:job_posting, :published) }
  let(:p3) { create(:job_posting, :published) }
  let(:p4) { create(:job_posting, :published) }
  let(:tanaka) { create_student }
  let(:sato) { create_student }
  let(:suzuki) { create_student }
  let(:takahashi) { create_student }

  # 内容の近さ（タグなし・カルチャーすべて中央）
  let(:content) { 0.10 }

  before do
    apply(tanaka, p1, %w[business culture])
    apply(tanaka, p2, %w[business])
    apply(sato, p1, %w[business])
    create(:candidacy, :scout, student_profile: suzuki, job_posting: p1).match_by_student(%w[culture])
    apply(takahashi, p4, %w[business])
    p3
    RecommendationStatsRebuildJob.perform_now
  end

  describe ".confidence（データ量に応じた信頼度 c(n) = n ÷ (n + 10)）" do
    it "0件なら0、10件なら 0.5" do
      expect(described_class.confidence(0)).to eq(0.0)
      expect(described_class.confidence(10)).to eq(0.5)
    end
  end

  describe ".posting_posting（募集どうし）" do
    it "f(P1, P2) = (1 − w) × 内容 + w × CF。w = 0.6 × c(小さいほうの人数1)" do
      f = described_class.posting_posting([ p1.id ], [ p2.id ]).sole.f

      cf = Recommendation::Behavior.posting_posting([ p1.id ], [ p2.id ]).sole.cf
      weight = 0.6 * (1.0 / 11)
      expect(f).to be_within(1e-9).of((1 - weight) * content + weight * cf)
    end

    it "片方の人数が0（P3）なら、行動の重みも0で、内容の近さだけになる" do
      expect(described_class.posting_posting([ p1.id ], [ p3.id ]).sole.f).to be_within(1e-9).of(content)
    end

    it "どちらにも興味があるが共通の学生がいない（P2 と P4）なら、CF = 0 として混ぜる" do
      weight = 0.6 * (1.0 / 11)

      expect(described_class.posting_posting([ p2.id ], [ p4.id ]).sole.f).to be_within(1e-9).of((1 - weight) * content)
    end

    it "内容の近さがある組は、すべて返す（共起がない組も含む）" do
      rows = described_class.posting_posting([ p1.id ], [ p2.id, p3.id, p4.id ])

      expect(rows.map(&:right_id)).to contain_exactly(p2.id, p3.id, p4.id)
    end
  end

  describe ".student_student（学生どうし）" do
    it "f(田中, 佐藤) = (1 − w) × 内容 + w × CF。w = 0.7 × c(小さいほうの件数1)" do
      f = described_class.student_student([ tanaka.id ], [ sato.id ]).sole.f

      cf = Recommendation::Behavior.student_student([ tanaka.id ], [ sato.id ]).sole.cf
      weight = 0.7 * (1.0 / 11)
      expect(f).to be_within(1e-9).of((1 - weight) * content + weight * cf)
    end
  end
end
