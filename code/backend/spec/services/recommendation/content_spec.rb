require "rails_helper"

# 内容の近さ Content のテスト（design/designs/処理設計_類似度.md の 7-2「Content」）。
# 設計書の「手計算した値と一致するかのテストを、組み合わせごとに厚めに書く」に従い、期待値はすべて手で計算したもの。
# 学生・募集は、画面から保存するときと同じメソッド（save_profile・save_posting）で作る（推薦の集計の項目数も一緒にできる）
RSpec.describe Recommendation::Content do
  # 大分類 A に中分類 a1・a2、大分類 B に中分類 b1
  let(:major_a) { create(:job_major_category) }
  let(:major_b) { create(:job_major_category) }
  let(:a1) { create(:job_middle_category, job_major_category: major_a) }
  let(:a2) { create(:job_middle_category, job_major_category: major_a) }
  let(:b1) { create(:job_middle_category, job_major_category: major_b) }
  let(:ruby) { create(:technology) }
  let(:rails) { create(:technology) }
  let(:go) { create(:technology) }
  let(:education) { create(:industry) }
  let(:finance) { create(:industry) }

  def create_student(**attributes)
    student = create(:student_user).student_profile
    expect(student.save_profile(attributes)).to be(true)
    student
  end

  def create_posting(**attributes)
    posting = create(:job_posting, :published)
    expect(posting.save_posting(attributes)).to be(true)
    posting
  end

  # 学生の技術（プログラミング歴）の行
  def skills(*technologies)
    technologies.map { |technology| { technology_id: technology.id, level: "v1" } }
  end

  # 結果を { [左の番号, 右の番号] => 近さ } にする
  def by_pair(rows)
    rows.to_h { |row| [ [ row.left_id, row.right_id ], row.content ] }
  end

  describe ".posting_student（募集×学生）" do
    # 募集 P：職種 a1（主）・b1（関連）、技術 Ruby・Rails、業界 教育、カルチャーはすべて0
    let(:posting) do
      create_posting(main_job_middle_category_ids: [ a1.id ], related_job_middle_category_ids: [ b1.id ],
                     technology_ids: [ ruby.id, rails.id ], industry_ids: [ education.id ])
    end

    it "設計書の例：職種1/3・技術1/2・業界1/2・カルチャー0.9 を重みで足すと 0.49" do
      # 学生 S：職種 a1・a2、技術 Ruby（と「その他」の Elm）、業界 教育・金融、働き方の好みは1軸目だけ2
      student = create_student(
        interested_job_middle_category_ids: [ a1.id, a2.id ],
        skills: skills(ruby) + [ { other_name: "Elm", level: "v1" } ],
        interested_industry_ids: [ education.id, finance.id ],
        personality_pace: 2
      )

      row = described_class.posting_student([ posting.id ], [ student.id ]).sole

      # 職種：重なり1 ÷（2 + 2 − 1）= 1/3、技術：1 ÷ 2（「その他」は数えない）、業界：1 ÷（1 + 2 − 1）、
      # カルチャー：(1 − 2/4 + 1 + 1 + 1 + 1) ÷ 5 = 0.9
      expected = 0.30 * (1.0 / 3) + 0.30 * 0.5 + 0.30 * 0.5 + 0.10 * 0.9
      expect(row).to have_attributes(left_id: posting.id, right_id: student.id)
      expect(row.content).to be_within(1e-9).of(expected)
    end

    it "中分類が1つも重ならないときは、大分類のジャカード係数 × 0.5 にする" do
      # 学生：職種 a2 だけ（大分類 A）。募集の大分類は A・B なので、大分類のジャカード係数は 1 ÷（2 + 1 − 1）= 1/2
      student = create_student(interested_job_middle_category_ids: [ a2.id ])

      content = described_class.posting_student([ posting.id ], [ student.id ]).sole.content

      # 職種 0.5 × 1/2、技術・業界は学生が未入力で0点、カルチャーはすべて一致で1
      expect(content).to be_within(1e-9).of(0.30 * 0.5 * 0.5 + 0.10 * 1.0)
    end

    it "学生が募集にない技術を持っていても、技術の点は下がらない" do
      student = create_student(skills: skills(ruby, go))

      content = described_class.posting_student([ posting.id ], [ student.id ]).sole.content

      # 技術：募集の Ruby・Rails のうち、学生が持っているのは Ruby だけ → 1/2（Go は関係ない）
      expect(content).to be_within(1e-9).of(0.30 * 0.5 + 0.10 * 1.0)
    end

    it "募集に技術が1つもなければ、技術は0点（未入力）" do
      no_technology = create_posting(industry_ids: [ education.id ])
      student = create_student(skills: skills(ruby), interested_industry_ids: [ education.id ])

      content = described_class.posting_student([ no_technology.id ], [ student.id ]).sole.content

      # 業界だけ一致（1 ÷（1 + 1 − 1）= 1）、カルチャーは1
      expect(content).to be_within(1e-9).of(0.30 * 1.0 + 0.10 * 1.0)
    end

    it "何も入力していない学生は、カルチャーの分（5軸すべて中央で一致）だけになる" do
      student = create_student(name: "未入力 太郎")

      expect(described_class.posting_student([ posting.id ], [ student.id ]).sole.content).to be_within(1e-9).of(0.10)
    end
  end

  describe ".student_student（学生どうし）" do
    # 学生 A：職種 a1・a2、技術 Ruby・Go、業界 教育、1軸目 2
    let(:student_a) do
      create_student(interested_job_middle_category_ids: [ a1.id, a2.id ], skills: skills(ruby, go),
                     interested_industry_ids: [ education.id ], personality_pace: 2)
    end
    # 学生 B：職種 a1、技術 Ruby、業界 教育・金融、1軸目 −2
    let(:student_b) do
      create_student(interested_job_middle_category_ids: [ a1.id ], skills: skills(ruby),
                     interested_industry_ids: [ education.id, finance.id ], personality_pace: -2)
    end

    it "職種1/2・技術1/2（ジャカード係数）・業界1/2・カルチャー0.8 を重みで足すと 0.53" do
      content = described_class.student_student([ student_a.id ], [ student_b.id ]).sole.content

      # 職種：1 ÷（2 + 1 − 1）、技術：1 ÷（2 + 1 − 1）、業界：1 ÷（1 + 2 − 1）、カルチャー：(1 − 4/4 + 4) ÷ 5 = 0.8
      expect(content).to be_within(1e-9).of(0.30 * 0.5 + 0.30 * 0.5 + 0.30 * 0.5 + 0.10 * 0.8)
    end

    it "自分自身との組は1になる（除くかどうかは呼ぶ側が決める）" do
      expect(described_class.student_student([ student_a.id ], [ student_a.id ]).sole.content).to be_within(1e-9).of(1.0)
    end
  end

  describe ".posting_posting（募集どうし）" do
    let(:processes) { create_list(:work_process, 2) }

    it "職種（大分類 × 0.5）・工程・技術・業界・カルチャーを重みで足すと 0.3575" do
      # 募集 A：職種 a1（主）・b1（関連）、工程 1つ目（メイン）・2つ目（関われる）、技術 Ruby・Rails、業界 教育
      posting_a = create_posting(
        main_job_middle_category_ids: [ a1.id ], related_job_middle_category_ids: [ b1.id ],
        main_work_process_ids: [ processes[0].id ], involved_work_process_ids: [ processes[1].id ],
        technology_ids: [ ruby.id, rails.id ], industry_ids: [ education.id ]
      )
      # 募集 B：職種 a2、工程 1つ目、技術 Ruby、業界 金融、カルチャーの1軸目 1
      posting_b = create_posting(
        main_job_middle_category_ids: [ a2.id ], main_work_process_ids: [ processes[0].id ],
        technology_ids: [ ruby.id ], industry_ids: [ finance.id ], culture_pace: 1
      )

      content = described_class.posting_posting([ posting_a.id ], [ posting_b.id ]).sole.content

      # 職種：中分類の重なりなし → 大分類 1 ÷（2 + 1 − 1）× 0.5 = 0.25、工程：1 ÷（2 + 1 − 1）、
      # 技術：1 ÷（2 + 1 − 1）、業界：0、カルチャー：(1 − 1/4 + 4) ÷ 5 = 0.95
      expected = 0.25 * 0.25 + 0.15 * 0.5 + 0.25 * 0.5 + 0.25 * 0.0 + 0.10 * 0.95
      expect(content).to be_within(1e-9).of(expected)
    end
  end

  describe "集まりの渡し方と top" do
    let(:posting) { create_posting(technology_ids: [ ruby.id ], industry_ids: [ education.id ]) }
    let(:other_posting) { create_posting(technology_ids: [ go.id ]) }
    # 募集 posting との近さ：best（技術・業界が一致）> middle（技術だけ一致）> worst（何もなし）
    let!(:best) { create_student(skills: skills(ruby), interested_industry_ids: [ education.id ]) }
    let!(:middle) { create_student(skills: skills(ruby)) }
    let!(:worst) { create_student(name: "未入力 花子") }

    it "1対多でも多対多でも、同じ組には同じ値を返す" do
      one_to_many = by_pair(described_class.posting_student([ posting.id ], [ best.id, middle.id, worst.id ]))
      many_to_many = by_pair(described_class.posting_student([ posting.id, other_posting.id ], [ best.id, middle.id, worst.id ]))

      expect(many_to_many.size).to eq(6)
      one_to_many.each { |pair, content| expect(many_to_many.fetch(pair)).to be_within(1e-9).of(content) }
    end

    it "Rails の問い合わせでも、番号の配列でも渡せる" do
      from_relation = by_pair(described_class.posting_student(JobPosting.where(id: posting.id), StudentProfile.where(id: best.id)))
      from_ids = by_pair(described_class.posting_student([ posting.id ], [ best.id ]))

      expect(from_relation).to eq(from_ids)
    end

    it "top を渡すと、近さの高い順にその件数だけ返す" do
      rows = described_class.posting_student([ posting.id ], [ worst.id, middle.id, best.id ], top: 2)

      expect(rows.map(&:right_id)).to eq([ best.id, middle.id ])
    end

    it "推薦の集計の行がない学生は、結果に出さない" do
      # ひな形で作っただけの学生（save_profile を通っていないので、集計の行がない）
      no_stats = create(:student_user).student_profile

      rows = described_class.posting_student([ posting.id ], [ best.id, no_stats.id ])

      expect(rows.map(&:right_id)).to eq([ best.id ])
    end

    it "空の集まりなら、何も返さない" do
      expect(described_class.posting_student([ posting.id ], [])).to eq([])
    end
  end
end
