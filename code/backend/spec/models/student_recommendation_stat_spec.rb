require "rails_helper"

# 学生ごとの推薦の集計のテスト（design/designs/データベース.md の 8-5 F、処理設計_類似度.md の 7-2・7-5）。
# - 件数と self_weight の数え直し（refresh_interests!。concerns/interest_stats.rb）
# - 項目数の数え直し（refresh_item_counts!）
# 期待値は、処理設計_類似度.md の式 W(S) = Σ u(P)、u(P) = 1 / log(1 + |B(P)|) で手計算したもの
RSpec.describe StudentRecommendationStat, type: :model do
  # 学生のプロフィールを作る
  def create_student
    create(:student_user).student_profile
  end

  # 応募理由を付けた応募（興味として数える）
  def apply(student, posting)
    candidacy = create(:candidacy, student_profile: student, job_posting: posting)
    candidacy.save_reasons!(%w[business])
    candidacy
  end

  describe ".refresh_interests!（件数と self_weight）" do
    # 田中：P1・P2 に応募（P2 は見送られた）／佐藤：P1 に応募、P2 からスカウト（まだ応じていない）／鈴木：P1 のスカウトにマッチ
    # → P1 に興味を示したのは3人、P2 は田中だけ
    let(:p1) { create(:job_posting, :published) }
    let(:p2) { create(:job_posting, :published) }
    let(:tanaka) { create_student }
    let(:sato) { create_student }
    let(:suzuki) { create_student }

    before do
      apply(tanaka, p1)
      apply(tanaka, p2).update!(status: :declined)
      apply(sato, p1)
      create(:candidacy, :scout, student_profile: sato, job_posting: p2)
      create(:candidacy, :scout, student_profile: suzuki, job_posting: p1).match_by_student(%w[culture])
    end

    it "件数と self_weight が手計算の値になる（見送られた応募は数え、応じていないスカウトは数えない）" do
      described_class.refresh_interests!([ tanaka.id, sato.id, suzuki.id ])

      # 田中：u(P1) + u(P2) = 1/log(4) + 1/log(2) ≒ 2.1640
      expect(tanaka.reload.recommendation_stat).to have_attributes(interest_count: 2)
      expect(tanaka.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(2))
      # 佐藤：u(P1) = 1/log(4) ≒ 0.7213（P2 のスカウトには応じていないので数えない）
      expect(sato.reload.recommendation_stat).to have_attributes(interest_count: 1)
      expect(sato.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4))
      # 鈴木：スカウトに応じたマッチは数える
      expect(suzuki.reload.recommendation_stat).to have_attributes(interest_count: 1)
      expect(suzuki.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4))
    end

    it "何度呼んでも同じ値になる" do
      2.times { described_class.refresh_interests!([ tanaka.id ]) }

      expect(described_class.where(student_profile: tanaka).count).to eq(1)
      expect(tanaka.reload.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(2))
    end

    it "渡した番号の行だけを書き換える" do
      described_class.refresh_interests!([ tanaka.id ])

      expect(sato.reload.recommendation_stat).to be_nil
    end

    it "興味が0件の学生は、行を作って0を入れる" do
      nobody = create_student

      described_class.refresh_interests!([ nobody.id ])

      expect(nobody.reload.recommendation_stat).to have_attributes(interest_count: 0, self_weight: 0)
    end

    it "古い値が入っていても、元データから数え直した値で上書きする" do
      described_class.create!(student_profile: sato, interest_count: 5, self_weight: 9.9)

      described_class.refresh_interests!([ sato.id ])

      expect(sato.reload.recommendation_stat.interest_count).to eq(1)
      expect(sato.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4))
    end

    it "項目数の列は書き換えない" do
      described_class.create!(student_profile: tanaka, job_middle_category_count: 3, industry_count: 2)

      described_class.refresh_interests!([ tanaka.id ])

      expect(tanaka.reload.recommendation_stat).to have_attributes(interest_count: 2, job_middle_category_count: 3, industry_count: 2)
    end
  end

  describe ".refresh_item_counts!（項目数）" do
    let(:student) { create_student }
    # 大分類 A に中分類2つ、大分類 B に中分類1つ
    let(:major_a) { create(:job_major_category) }
    let(:major_b) { create(:job_major_category) }
    let(:middle_a1) { create(:job_middle_category, job_major_category: major_a) }
    let(:middle_a2) { create(:job_middle_category, job_major_category: major_a) }
    let(:middle_b1) { create(:job_middle_category, job_major_category: major_b) }

    before do
      # 画面から保存するときと同じメソッドで、付属テーブルを作る
      student.save_profile(
        interested_job_middle_category_ids: [ middle_a1.id, middle_a2.id, middle_b1.id ],
        interested_industry_ids: [ create(:industry).id, create(:industry).id ],
        skills: [
          { technology_id: create(:technology).id, level: "v1" },
          { technology_id: create(:technology).id, level: "v2" },
          { other_name: "Elm", level: "v1" }
        ]
      )
    end

    it "中分類・大分類（重複は1つ）・技術（「その他」は除く）・業界の数を数える" do
      described_class.refresh_item_counts!([ student.id ])

      expect(student.reload.recommendation_stat).to have_attributes(
        job_middle_category_count: 3,
        job_major_category_count: 2,
        technology_count: 2,
        industry_count: 2
      )
    end

    it "何も入力していない学生は、すべて0になる（複数の番号をまとめて渡せる）" do
      empty = create_student

      described_class.refresh_item_counts!([ student.id, empty.id ])

      expect(empty.reload.recommendation_stat).to have_attributes(
        job_middle_category_count: 0,
        job_major_category_count: 0,
        technology_count: 0,
        industry_count: 0
      )
    end

    it "入力を減らしてから数え直すと、減った数で上書きする" do
      described_class.refresh_item_counts!([ student.id ])
      student.save_profile(interested_job_middle_category_ids: [ middle_b1.id ], interested_industry_ids: [], skills: [])

      described_class.refresh_item_counts!([ student.id ])

      expect(student.reload.recommendation_stat).to have_attributes(
        job_middle_category_count: 1,
        job_major_category_count: 1,
        technology_count: 0,
        industry_count: 0
      )
    end

    it "件数と self_weight の列は書き換えない" do
      described_class.create!(student_profile: student, interest_count: 2, self_weight: 1.5)

      described_class.refresh_item_counts!([ student.id ])

      expect(student.reload.recommendation_stat).to have_attributes(interest_count: 2, self_weight: 1.5, job_middle_category_count: 3)
    end
  end
end
