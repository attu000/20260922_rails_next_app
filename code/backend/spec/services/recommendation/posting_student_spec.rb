require "rails_helper"

# 募集と学生のおすすめ度 f(P, S) のテスト（design/designs/処理設計_類似度.md の 7-2「推薦の本体」）。
# I・U の材料になる募集どうし・学生どうしの近さは、13-2 でテスト済みの Recommendation::Similarity から取り、
# 重み・平均の取り方・自分自身の除き方を、手計算と突き合わせる。
# タグのない募集・学生を使うので、内容の近さはカルチャーの 0.10 だけになる
RSpec.describe Recommendation::PostingStudent do
  def create_student
    create(:student_user).student_profile
  end

  def apply(student, posting, reasons)
    candidacy = create(:candidacy, student_profile: student, job_posting: posting)
    candidacy.save_reasons!(reasons)
    candidacy
  end

  # 田中：P1・P2、佐藤：P1、鈴木：P1（スカウトにマッチ）、高橋：P4。P3 は興味なし。新井は何もしていない
  let(:p1) { create(:job_posting, :published) }
  let(:p2) { create(:job_posting, :published) }
  let(:p3) { create(:job_posting, :published) }
  let(:p4) { create(:job_posting, :published) }
  let(:tanaka) { create_student }
  let(:sato) { create_student }
  let(:suzuki) { create_student }
  let(:takahashi) { create_student }
  let(:arai) { create_student }

  before do
    apply(tanaka, p1, %w[business culture])
    apply(tanaka, p2, %w[business])
    apply(sato, p1, %w[business])
    create(:candidacy, :scout, student_profile: suzuki, job_posting: p1).match_by_student(%w[culture])
    apply(takahashi, p4, %w[business])
    [ p3, arai ]
    RecommendationStatsRebuildJob.perform_now
  end

  # 内容の近さを、呼ぶ側（13-3b）と同じく Recommendation::Content で計算して渡す
  def contents_for_student(student, postings)
    Recommendation::Content.posting_student(postings.map(&:id), [ student.id ]).to_h { |row| [ row.left_id, row.content ] }
  end

  def contents_for_posting(posting, students)
    Recommendation::Content.posting_student([ posting.id ], students.map(&:id)).to_h { |row| [ row.right_id, row.content ] }
  end

  # 募集どうし・学生どうしの近さ（13-2 の部品）
  def posting_f(posting, other)
    Recommendation::Similarity.posting_posting([ posting.id ], [ other.id ]).sole.f
  end

  def student_f(student, other)
    Recommendation::Similarity.student_student([ student.id ], [ other.id ]).sole.f
  end

  # c(n) = n ÷ (n + 10)、γ = 0.3
  def neighbor_weight(count)
    0.3 * count / (count + 10.0)
  end

  describe ".for_student（学生1人から見た募集たち）" do
    it "学生の件数も募集の人数も0なら、f は内容の近さだけ" do
      f = described_class.for_student(arai, [ p3.id ], contents_for_student(arai, [ p3 ]))

      expect(f.fetch(p3.id)).to be_within(1e-9).of(0.10)
    end

    it "田中から見た P3：I は P3 と田中の興味（P1・P2）の近さの平均。P3 は人数0なので U の重みは0" do
      f = described_class.for_student(tanaka, [ p3.id ], contents_for_student(tanaka, [ p3 ])).fetch(p3.id)

      i = (posting_f(p3, p1) + posting_f(p3, p2)) / 2
      weight_i = neighbor_weight(2)
      expect(f).to be_within(1e-9).of((1 - weight_i) * 0.10 + weight_i * i)
    end

    it "田中から見た P1：I は P1 自身を除いて P2 だけ、U は田中自身を除いて佐藤・鈴木" do
      f = described_class.for_student(tanaka, [ p1.id ], contents_for_student(tanaka, [ p1 ])).fetch(p1.id)

      i = posting_f(p1, p2)
      u = (student_f(tanaka, sato) + student_f(tanaka, suzuki)) / 2
      weight_i = neighbor_weight(2)
      weight_u = neighbor_weight(3)
      expect(f).to be_within(1e-9).of((1 - weight_i - weight_u) * 0.10 + weight_i * i + weight_u * u)
    end

    it "募集が空なら、空の結果を返す" do
      expect(described_class.for_student(tanaka, [], {})).to eq({})
    end
  end

  describe ".for_posting（募集1件から見た学生たち）" do
    it "P1 から見た高橋：U は P1 の3人との近さの平均、I は高橋の興味（P4）との近さ" do
      f = described_class.for_posting(p1, [ takahashi.id ], contents_for_posting(p1, [ takahashi ])).fetch(takahashi.id)

      i = posting_f(p1, p4)
      u = (student_f(takahashi, tanaka) + student_f(takahashi, sato) + student_f(takahashi, suzuki)) / 3
      weight_i = neighbor_weight(1)
      weight_u = neighbor_weight(3)
      expect(f).to be_within(1e-9).of((1 - weight_i - weight_u) * 0.10 + weight_i * i + weight_u * u)
    end

    it "除いたあとに相手がいなければ、その値は0（P4 から見た高橋：U は高橋自身しかいないので0）" do
      f = described_class.for_posting(p4, [ takahashi.id ], contents_for_posting(p4, [ takahashi ])).fetch(takahashi.id)

      # I も、高橋の興味は P4 自身だけなので0。重みは件数で決まる（w_I = 0.3 × 1/11、w_U = 0.3 × 1/11）
      weight = neighbor_weight(1)
      expect(f).to be_within(1e-9).of((1 - 2 * weight) * 0.10)
    end
  end

  describe "2つの向き" do
    it "同じ組なら、学生から見ても募集から見ても同じ値になる" do
      [ [ tanaka, p1 ], [ tanaka, p3 ], [ takahashi, p1 ], [ sato, p2 ] ].each do |student, posting|
        from_student = described_class.for_student(student, [ posting.id ], contents_for_student(student, [ posting ])).fetch(posting.id)
        from_posting = described_class.for_posting(posting, [ student.id ], contents_for_posting(posting, [ student ])).fetch(student.id)

        expect(from_posting).to be_within(1e-9).of(from_student)
      end
    end
  end

  describe ".weights と .power_mean" do
    it "重みの合計は1。件数0なら、その重みは0" do
      expect(described_class.weights(0, 0)).to eq([ 1.0, 0.0, 0.0 ])
      expect(described_class.weights(2, 3).sum).to be_within(1e-9).of(1.0)
    end

    it "p = 1 なら普通の平均。p = 2 なら二乗の平均の平方根。空なら0" do
      expect(described_class.power_mean([ 0.2, 0.4 ])).to be_within(1e-9).of(0.3)
      expect(described_class.power_mean([])).to eq(0.0)

      stub_const("Recommendation::Parameters::POWER_MEAN_EXPONENT", 2)
      expect(described_class.power_mean([ 0.2, 0.4 ])).to be_within(1e-9).of(Math.sqrt((0.04 + 0.16) / 2))
    end
  end
end
