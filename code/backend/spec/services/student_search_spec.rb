require "rails_helper"

# 学生検索の本体（app/services/student_search.rb）のテスト。
# 条件で結果を減らさず、指定した条件を全部満たす学生を合致、1つでも外れる学生を合致外にする。
# 詳しくは design/designs/API設計.md の 16-3 ㉒、処理設計_類似度.md の 7-3、その他決め事.md の 5-4・5-6・5-10
RSpec.describe StudentSearch do
  let(:company) { create(:company_user).company_profile }

  def search(params = {}, job_posting: nil)
    StudentSearch.new(job_posting: job_posting, params: params)
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

    it "募集を選べば、おすすめ順が既定になる。今は全員0点なので、並びは最終活動の順と同じ（PR214）" do
      job_posting = create(:job_posting, :published, company_profile: company)

      result = search({ grades: [ "undergrad_3" ] }, job_posting: job_posting)

      # おすすめ順は点数を付けて Ruby で並べるので、配列が返る
      expect(result.ordered).to be_an(Array)
      expect(result.ordered.map(&:id)).to eq(expected_order)
    end

    it "募集を選ばなければ、おすすめ順を指定しても最終活動の順になる（窓口では 422 にしてある）" do
      result = search({ grades: [ "undergrad_3" ], sort: "recommended" })

      expect(result.ordered).not_to be_an(Array)
      expect(result.ordered.map(&:id)).to eq(expected_order)
    end
  end

  describe "フリーワード" do
    it "自己PRの3つと、プログラミング歴の「その他」の名前で合う。大文字と小文字は区別しない" do
      by_columns = %i[self_pr_strength self_pr_weakness self_pr_future].map do |column|
        create_student(column => "Ruby が好きです")
      end
      by_other_skill = create_student.tap { |student| student.student_skills.create!(other_name: "Ruby 製の自作ツール", level: :v1) }
      create_student(self_pr_strength: "Go が好きです")

      expect(matched_ids(q: "ruby")).to contain_exactly(*by_columns.map(&:id), by_other_skill.id)
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
