require "rails_helper"

# 募集ごとの推薦の集計のテスト（design/designs/データベース.md の 8-5 F、処理設計_類似度.md の 7-2・7-5）。
# - 件数と self_weight の数え直し（refresh_interests!。concerns/interest_stats.rb の、募集の列でまとめる側）
# - 応募・マッチ1件で、直接関係のない募集の self_weight も変わること（ジョブが数え直す範囲の確認。7-5 の「応募・マッチ時の手順」）
# - 項目数の数え直し（refresh_item_counts!）
# 期待値は、処理設計_類似度.md の式 W(P) = Σ u(S)、u(S) = 1 / log(1 + |A(S)|) で手計算したもの
RSpec.describe JobPostingRecommendationStat, type: :model do
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
    # 学生の集計のテストと同じ例。
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
    end

    it "件数と self_weight が手計算の値になる" do
      described_class.refresh_interests!([ p1.id, p2.id, p3.id ])

      # P1：u(田中) + u(佐藤) + u(鈴木) = 1/log(3) + 1/log(2) + 1/log(2) ≒ 3.7956
      expect(p1.reload.recommendation_stat).to have_attributes(interest_count: 3)
      expect(p1.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(3) + 2 / Math.log(2))
      # P2：u(田中) = 1/log(3) ≒ 0.9102（佐藤のスカウトには応じていないので数えない）
      expect(p2.reload.recommendation_stat).to have_attributes(interest_count: 1)
      expect(p2.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(3))
      # P3：やりとりがないので0
      expect(p3.reload.recommendation_stat).to have_attributes(interest_count: 0, self_weight: 0)
    end

    it "佐藤が P2 のスカウトにマッチすると、新しい興味のない P1 の self_weight も変わる" do
      described_class.refresh_interests!([ p1.id, p2.id ])
      StudentRecommendationStat.refresh_interests!([ tanaka.id, sato.id, suzuki.id ])

      sato_scout.match_by_student(%w[technologies])
      # ジョブが数え直す範囲：P2 に興味を示した学生（田中・佐藤）と、佐藤が興味を示した募集（P1・P2）
      StudentRecommendationStat.refresh_interests!([ tanaka.id, sato.id ])
      described_class.refresh_interests!([ p1.id, p2.id ])

      # P1：佐藤の件数が2になり、u(佐藤) が 1/log(2) → 1/log(3) に下がる。1/log(3) + 1/log(3) + 1/log(2) ≒ 3.2632
      expect(p1.reload.recommendation_stat).to have_attributes(interest_count: 3)
      expect(p1.recommendation_stat.self_weight).to be_within(1e-9).of(2 / Math.log(3) + 1 / Math.log(2))
      # P2：u(田中) + u(佐藤) = 2/log(3) ≒ 1.8205
      expect(p2.reload.recommendation_stat).to have_attributes(interest_count: 2)
      expect(p2.recommendation_stat.self_weight).to be_within(1e-9).of(2 / Math.log(3))
      # 田中：u(P1) + u(P2) = 1/log(4) + 1/log(3) ≒ 1.6316（P2 の人数が2になった）
      expect(tanaka.reload.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3))
      # 佐藤：件数2、u(P1) + u(P2) ≒ 1.6316
      expect(sato.reload.recommendation_stat).to have_attributes(interest_count: 2)
      expect(sato.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4) + 1 / Math.log(3))
      # 鈴木：P1 の人数は変わらないので、そのまま
      expect(suzuki.reload.recommendation_stat.self_weight).to be_within(1e-9).of(1 / Math.log(4))
    end

    it "項目数の列は書き換えない" do
      described_class.create!(job_posting: p1, work_process_count: 4)

      described_class.refresh_interests!([ p1.id ])

      expect(p1.reload.recommendation_stat).to have_attributes(interest_count: 3, work_process_count: 4)
    end
  end

  describe ".refresh_item_counts!（項目数）" do
    let(:posting) { create(:job_posting) }
    # 大分類 A に中分類2つ、大分類 B に中分類1つ
    let(:major_a) { create(:job_major_category) }
    let(:major_b) { create(:job_major_category) }
    let(:middle_a1) { create(:job_middle_category, job_major_category: major_a) }
    let(:middle_a2) { create(:job_middle_category, job_major_category: major_a) }
    let(:middle_b1) { create(:job_middle_category, job_major_category: major_b) }

    before do
      # 画面から保存するときと同じメソッドで、中間テーブルを作る
      posting.save_posting(
        main_job_middle_category_ids: [ middle_a1.id ],
        related_job_middle_category_ids: [ middle_a2.id, middle_b1.id ],
        main_work_process_ids: [ create(:work_process).id ],
        involved_work_process_ids: [ create(:work_process).id, create(:work_process).id ],
        technology_ids: [ create(:technology).id, create(:technology).id ],
        industry_ids: [ create(:industry).id ]
      )
    end

    it "中分類（主・関連）・大分類（重複は1つ）・工程（メイン・関われる）・技術・業界の数を数える" do
      described_class.refresh_item_counts!([ posting.id ])

      expect(posting.reload.recommendation_stat).to have_attributes(
        job_middle_category_count: 3,
        job_major_category_count: 2,
        work_process_count: 3,
        technology_count: 2,
        industry_count: 1
      )
    end

    it "何も入力していない募集は、すべて0になる（複数の番号をまとめて渡せる）" do
      empty = create(:job_posting)

      described_class.refresh_item_counts!([ posting.id, empty.id ])

      expect(empty.reload.recommendation_stat).to have_attributes(
        job_middle_category_count: 0,
        job_major_category_count: 0,
        work_process_count: 0,
        technology_count: 0,
        industry_count: 0
      )
    end

    it "件数と self_weight の列は書き換えない" do
      # 行は、上の save_posting で自動でできている（順12 の 12-2）。件数と self_weight に、わざと値を入れておく
      posting.recommendation_stat.update!(interest_count: 7, self_weight: 2.5)

      described_class.refresh_item_counts!([ posting.id ])

      expect(posting.reload.recommendation_stat).to have_attributes(interest_count: 7, self_weight: 2.5, work_process_count: 3)
    end
  end
end
