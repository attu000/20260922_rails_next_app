require "rails_helper"

# 学生検索の本体（app/services/student_search.rb）のテスト。
# 条件で結果を減らさず、指定した条件を全部満たす学生を合致、1つでも外れる学生を合致外にする。
# 詳しくは design/designs/API設計.md の 16-3 ㉒、処理設計_類似度.md の 7-3、その他決め事.md の 5-4・5-6・5-10
RSpec.describe StudentSearch do
  let(:company) { create(:company_user).company_profile }

  def search(params = {}, job_posting: nil)
    StudentSearch.new(company: company, job_posting: job_posting, params: params)
  end

  # 検索に出る学生の番号（ページ分けの前の、並べた一覧）
  def listed_ids(job_posting: nil)
    search({}, job_posting: job_posting).ordered.map(&:id)
  end

  # 条件に合う学生の番号（すべての学生の中から）
  def matched_ids(params)
    search(params).matched_ids_in(StudentProfile.ids)
  end

  # 学生を作る。最終活動日と、プロフィールの値を指定できる
  def create_student(last_active_on: Time.zone.today, **attributes)
    student = create(:student_user, last_active_on: last_active_on).student_profile
    student.update!(attributes) if attributes.any?
    student
  end

  def add_skill(student, technology, level)
    StudentSkill.create!(student_profile: student, technology: technology, level: level)
  end

  describe "対象" do
    it "30日以内に活動した学生だけを並べ、条件がなければ全員が合致。ちょうど30日前は出し、31日前と最終活動日が空欄の学生は出さない（PR216）" do
      today = create_student
      thirty_days_ago = create_student(last_active_on: Time.zone.today - 30)
      create_student(last_active_on: Time.zone.today - 31)
      create_student(last_active_on: nil)

      result = search

      expect(result.ordered.map(&:id)).to contain_exactly(today.id, thirty_days_ago.id)
      expect(result.matched_count).to eq(2)
    end
  end

  # もうスカウトした・見送った・マッチした学生は出さない（PR220）。未対応応募（応募の未マッチ）だけは残す
  describe "やりとりによる除外" do
    let(:posting) { create(:job_posting, :published, company_profile: company) }

    def create_candidacy(student, job_posting, origin, status)
      create(:candidacy, student_profile: student, job_posting: job_posting, origin: origin, status: status)
    end

    context "募集を選んだとき" do
      it "その募集とスカウト済み・見送り・マッチ以降のやりとりがある学生は出さない。未対応応募と、やりとりのない学生は出す" do
        # 出さない7人（スカウト済み、スカウトの見送り・マッチ、応募の見送り・マッチ・合格・不合格）
        [
          %i[scout unmatched], %i[scout declined], %i[scout matched],
          %i[application declined], %i[application matched], %i[application passed], %i[application failed]
        ].each { |origin, status| create_candidacy(create_student, posting, origin, status) }
        pending_application = create_student.tap { |student| create_candidacy(student, posting, :application, :unmatched) }
        no_candidacy = create_student

        expect(listed_ids(job_posting: posting)).to contain_exactly(pending_application.id, no_candidacy.id)
      end

      it "ほかの募集とだけやりとりがある学生は出す" do
        other_posting = create(:job_posting, :published, company_profile: company)
        student = create_student.tap { |s| create_candidacy(s, other_posting, :scout, :matched) }

        expect(listed_ids(job_posting: posting)).to eq([ student.id ])
      end

      it "除いた学生は、人数（全◯人・条件に合う◯人）にも入らない" do
        create_student.tap { |student| create_candidacy(student, posting, :scout, :unmatched) }
        create_student

        result = search({}, job_posting: posting)

        expect(result.ordered.size).to eq(1)
        expect(result.matched_count).to eq(1)
      end
    end

    context "募集を選ばないとき" do
      let!(:other_posting) { create(:job_posting, :published, company_profile: company) }

      it "自社の掲載中の募集すべてで、もうすることがない学生は出さない。1つでも残っていれば出す" do
        done_with_all = create_student.tap do |student|
          create_candidacy(student, posting, :scout, :unmatched)
          create_candidacy(student, other_posting, :application, :declined)
        end
        one_left = create_student.tap { |student| create_candidacy(student, posting, :scout, :matched) }
        pending_application = create_student.tap do |student|
          create_candidacy(student, posting, :scout, :unmatched)
          create_candidacy(student, other_posting, :application, :unmatched)
        end

        expect(listed_ids).not_to include(done_with_all.id)
        expect(listed_ids).to contain_exactly(one_left.id, pending_application.id)
      end

      it "非公開・終了の募集は数えない。掲載中の募集すべてで済んでいれば出さず、終了の募集のやりとりで数を補っても出す" do
        closed = create(:job_posting, :closed, company_profile: company)
        # 掲載中の2件とも済んでいる（終了の募集とはやりとりがないが、数えないので関係ない）
        done_with_published = create_student.tap do |s|
          create_candidacy(s, posting, :scout, :unmatched)
          create_candidacy(s, other_posting, :scout, :unmatched)
        end
        # 掲載中の1件と終了の1件で済んでいる。掲載中のもう1件が残っているので出す
        one_published_left = create_student.tap do |s|
          create_candidacy(s, posting, :scout, :unmatched)
          create_candidacy(s, closed, :scout, :matched)
        end

        expect(listed_ids).not_to include(done_with_published.id)
        expect(listed_ids).to include(one_published_left.id)
      end

      it "他社の募集とのやりとりは関係しない" do
        others = create(:job_posting, :published)
        student = create_student.tap { |s| create_candidacy(s, others, :scout, :matched) }

        expect(listed_ids).to eq([ student.id ])
      end
    end

    it "掲載中の募集が1件もない会社では、誰も除かない" do
      closed = create(:job_posting, :closed, company_profile: company)
      student = create_student.tap { |s| create_candidacy(s, closed, :scout, :matched) }

      expect(listed_ids).to eq([ student.id ])
    end
  end

  describe "並び順" do
    # 合致・合致外 × 最終活動の新旧の4人。学年で合う・合わないを分ける
    let!(:matched_new) { create_student(grade: :undergrad_3, last_active_on: Time.zone.today - 1) }
    let!(:matched_old) { create_student(grade: :undergrad_3, last_active_on: Time.zone.today - 5) }
    let!(:unmatched_new) { create_student(grade: :master_1, last_active_on: Time.zone.today) }
    let!(:unmatched_old) { create_student(grade: :master_1, last_active_on: Time.zone.today - 10) }
    let(:expected_order) { [ matched_new, matched_old, unmatched_new, unmatched_old ].map(&:id) }

    it "合致の群がすべて先。各群の中は最終活動の新しい順" do
      expect(search({ grades: [ "undergrad_3" ] }).ordered.map(&:id)).to eq(expected_order)
    end

    it "募集を選べば、おすすめ順が既定になる。推薦の集計の行がない学生は上位の並びに入らないので、最終活動の順と同じ並び" do
      job_posting = create(:job_posting, :published, company_profile: company)
      expect(StudentRecommender).to receive(:ranked_ids).and_call_original

      # ordered は呼ぶたびに上位の並びを計算し直すので、1回だけ呼ぶ
      ordered = search({ grades: [ "undergrad_3" ] }, job_posting: job_posting).ordered

      # おすすめ順も SQL で並べる（PR295）
      expect(ordered).to be_a(ActiveRecord::Relation)
      expect(ordered.map(&:id)).to eq(expected_order)
    end

    it "募集を選ばなければ、おすすめ順を指定しても最終活動の順になり、上位の並びを計算しない（窓口では 422 にしてある）" do
      expect(StudentRecommender).not_to receive(:ranked_ids)

      result = search({ grades: [ "undergrad_3" ], sort: "recommended" })

      expect(result.ordered.map(&:id)).to eq(expected_order)
    end
  end

  # 順13：おすすめ順は、群ごとの上位 R 人を f の高い順に並べ、残りを最終活動の新しい順に続ける（処理設計_類似度.md の 7-3・7-5。PR280）
  describe "おすすめ順の、上位と残りの並び" do
    let(:ruby) { create(:technology) }
    # 募集は Ruby を使う。Ruby を持つ学生は内容の近さ 0.40、ほかは 0.10
    let(:job_posting) do
      create(:job_posting, :published, company_profile: company).tap { |posting| posting.save_posting(technology_ids: [ ruby.id ]) }
    end

    it "R = 1 なら、合う群の上位1人（最終活動は古いが点が最も高い）→ 合う群の残り（最終活動の新しい順）→ 合わない群も同じ形" do
      stub_const("Recommendation::Parameters::RERANK_SIZE", 1)
      matched_best = create_student(grade: :undergrad_3, last_active_on: Time.zone.today - 5).tap { |student| add_skill(student, ruby, :v1) }
      matched_middle = create_student(grade: :undergrad_3, last_active_on: Time.zone.today - 3)
      matched_new = create_student(grade: :undergrad_3, last_active_on: Time.zone.today - 1)
      unmatched_best = create_student(grade: :master_1, last_active_on: Time.zone.today - 10).tap { |student| add_skill(student, ruby, :v1) }
      unmatched_new = create_student(grade: :master_1, last_active_on: Time.zone.today - 2)
      job_posting
      RecommendationStatsRebuildJob.perform_now

      ordered = search({ grades: [ "undergrad_3" ] }, job_posting: job_posting).ordered

      expect(ordered.map(&:id)).to eq([
        matched_best.id, matched_new.id, matched_middle.id,
        unmatched_best.id, unmatched_new.id
      ])
    end
  end

  describe "フリーワード" do
    it "自己PRの3つと、資格名、プログラミング歴の「その他」の名前で合う。大文字と小文字は区別しない" do
      by_columns = %i[self_pr_strength self_pr_weakness self_pr_future].map do |column|
        create_student(column => "Ruby が好きです")
      end
      by_other_skill = create_student.tap { |student| student.student_skills.create!(other_name: "Ruby 製の自作ツール", level: :v1) }
      # 資格名（順17）。資格を2つ持っていても1人として数える（表を結合せず、サブクエリで探すため）
      by_certification = create_student.tap do |student|
        student.student_certifications.create!(name: "Ruby技術者認定試験 Silver")
        student.student_certifications.create!(name: "Ruby技術者認定試験 Gold")
      end
      create_student(self_pr_strength: "Go が好きです")

      expect(matched_ids(q: "ruby")).to contain_exactly(*by_columns.map(&:id), by_other_skill.id, by_certification.id)
    end

    it "名前と大学名は対象にしない" do
      create_student(name: "Ruby 太郎", university_other_name: "Ruby 大学")

      expect(matched_ids(q: "Ruby")).to eq([])
    end

    it "空白で区切ると、すべての語を含む学生だけが合う" do
      both = create_student(self_pr_strength: "Ruby と Go")
      create_student(self_pr_strength: "Ruby だけ")

      expect(matched_ids(q: "Ruby　Go")).to eq([ both.id ])
    end
  end

  describe "稼働条件の数値" do
    # 列 => [指定する値, 合う学生の値, もっと大きい値, 合わない学生の値]
    {
      work_days_per_week: [ 3, 3, 5, 2 ],
      work_hours_per_day: [ 4, 4, 8, 3 ],
      duration_months: [ 6, 6, 12, 3 ]
    }.each do |column, (value, equal, larger, smaller)|
      it "#{column}：学生の値が指定した値以上なら合う。小さい値と空欄は合わない" do
        equal_student = create_student(column => equal)
        larger_student = create_student(column => larger)
        create_student(column => smaller)
        create_student

        expect(matched_ids(column => value)).to contain_exactly(equal_student.id, larger_student.id)
      end
    end
  end

  describe "開始時期" do
    let(:this_month) { Time.zone.today.beginning_of_month }

    it "学生の開始可能月が、指定した月以前なら合う。後の月と空欄は合わない" do
      same = create_student(available_from: this_month.next_month)
      earlier = create_student(available_from: this_month)
      create_student(available_from: this_month.next_month(2))
      create_student

      expect(matched_ids(start_month: this_month.next_month.iso8601)).to contain_exactly(same.id, earlier.id)
    end

    it "指定した月が今月より前なら、条件として使わない（空欄の学生も含めて全員が合う）" do
      students = [ create_student(available_from: this_month.next_month(2)), create_student ]

      expect(matched_ids(start_month: this_month.prev_month.iso8601)).to match_array(students.map(&:id))
    end
  end

  describe "勤務形態と勤務地" do
    let(:prefecture) { create(:prefecture) }

    it "勤務形態：学生がその勤務形態を「可能」にしていれば合う" do
      can = create_student(can_onsite: true)
      create_student(can_onsite: false)

      expect(matched_ids(work_style: "onsite")).to eq([ can.id ])
    end

    it "勤務地：出社できる都道府県に含まれれば合う。登録していない学生は合わない" do
      commutable = create_student.tap { |student| student.update!(commutable_prefecture_ids: [ prefecture.id ]) }
      create_student.tap { |student| student.update!(commutable_prefecture_ids: [ create(:prefecture).id ]) }
      create_student

      expect(matched_ids(prefecture_id: prefecture.id)).to eq([ commutable.id ])
    end

    it "勤務形態がフルリモートなら、勤務地は使わない" do
      remote = create_student(can_full_remote: true)

      expect(matched_ids(work_style: "full_remote", prefecture_id: prefecture.id)).to eq([ remote.id ])
    end
  end

  # 似た学生のポップアップで、「この募集の稼働条件で選ぶ」と同じ条件を作る（PR313）
  describe ".work_condition_params（募集の稼働条件から条件を作る）" do
    it "募集の下限・開始月・勤務形態・都道府県を条件にする。空欄の項目は入れない" do
      prefecture = create(:prefecture)
      job_posting = create(:job_posting, min_work_days_per_week: 3, min_duration_months: 6,
                                         work_style: :onsite, prefecture: prefecture)

      expect(described_class.work_condition_params(job_posting)).to eq(
        work_days_per_week: 3, duration_months: 6, work_style: "onsite", prefecture_id: prefecture.id
      )
    end

    it "作った条件で、募集の稼働条件に合う学生が合う" do
      job_posting = create(:job_posting, min_work_days_per_week: 3, start_month: Time.zone.today.next_month.beginning_of_month)
      matched = create_student(work_days_per_week: 3, available_from: Time.zone.today.beginning_of_month)
      create_student(work_days_per_week: 3, available_from: Time.zone.today.next_month(2).beginning_of_month)
      create_student(work_days_per_week: 2)

      expect(matched_ids(described_class.work_condition_params(job_posting))).to eq([ matched.id ])
    end
  end

  describe "使用技術とレベル" do
    let(:ruby) { create(:technology) }
    let(:go) { create(:technology) }

    it "選んだ技術をすべて持っている学生だけが合う" do
      both = create_student
      add_skill(both, ruby, :v1)
      add_skill(both, go, :v1)
      add_skill(create_student, ruby, :v1)

      expect(matched_ids(technology_ids: [ ruby.id, go.id ])).to eq([ both.id ])
    end

    it "レベルも選ぶと、選んだ技術すべてがそのレベル以上の学生だけが合う" do
      high = create_student
      add_skill(high, ruby, :v3)
      add_skill(high, go, :v2)
      low = create_student
      add_skill(low, ruby, :v3)
      add_skill(low, go, :v1)

      expect(matched_ids(technology_ids: [ ruby.id, go.id ], min_level: "v2")).to eq([ high.id ])
    end

    it "レベルだけを選んでも、条件として使わない" do
      student = create_student
      add_skill(student, ruby, :v1)

      expect(matched_ids(min_level: "v4")).to eq([ student.id ])
    end
  end

  describe "職種" do
    it "興味のある職種のどれか1つが一致すれば合う。大分類は、その中の中分類すべてに広げる" do
      major = create(:job_major_category)
      backend = create(:job_middle_category, job_major_category: major)
      frontend = create(:job_middle_category, job_major_category: major)
      other = create(:job_middle_category)
      by_backend = create_student.tap { |student| student.update!(interested_job_middle_category_ids: [ backend.id, other.id ]) }
      by_frontend = create_student.tap { |student| student.update!(interested_job_middle_category_ids: [ frontend.id ]) }
      create_student.tap { |student| student.update!(interested_job_middle_category_ids: [ other.id ]) }

      expect(matched_ids(job_middle_category_ids: [ backend.id ])).to eq([ by_backend.id ])
      expect(matched_ids(job_major_category_ids: [ major.id ])).to contain_exactly(by_backend.id, by_frontend.id)
    end
  end

  describe "学年・卒業年度・活動状況" do
    it "それぞれ、どれかに当てはまれば合う。空欄は合わない" do
      undergrad = create_student(grade: :undergrad_3, graduation_year: 2028, activity_status: :job_hunting)
      master = create_student(grade: :master_1, graduation_year: 2027, activity_status: :not_looking)
      create_student(grade: :doctoral, graduation_year: 2030, activity_status: :skill_up)
      blank = create_student

      expect(matched_ids(grades: %w[undergrad_3 master_1])).to contain_exactly(undergrad.id, master.id)
      expect(matched_ids(graduation_years: %w[2027 2028])).to contain_exactly(undergrad.id, master.id)
      # 「今は探していない」の学生も、選べば合う（結果から外すことはしない）
      expect(matched_ids(activity_statuses: %w[job_hunting not_looking])).to contain_exactly(undergrad.id, master.id)
      expect(matched_ids(grades: %w[undergrad_3])).not_to include(blank.id)
    end

    it "知らない名前や、整数でない卒業年度は「指定なし」として扱う（全員が合う）" do
      students = [ create_student(grade: :undergrad_3, graduation_year: 2028), create_student ]

      expect(matched_ids(grades: %w[unknown], graduation_years: %w[abc], activity_statuses: %w[unknown]))
        .to match_array(students.map(&:id))
    end
  end
end
