# 内容の近さ Content（構造化データの近さ。design/designs/処理設計_類似度.md の 7-2「Content」）。
# 組み合わせ（募集×学生、学生どうし、募集どうし）ごとに、SQL だけで計算する。Ruby 版は持たない（PR288）。
# どの組み合わせも、数千〜10万件の相手について計算する場面があるため（7-5）。
#
# 2つの集まり（左と右）を受け取り、すべての組の近さを返す。1対10万（学生検索の手順1）でも、
# 100対200（リランキングの U）でも同じ部品を使う。自分自身との組を除くかどうかは、呼ぶ側が決める。
#
# 計算のしかた
#   項目ごとの点 s_k を、重み w_k（Recommendation::Parameters::CONTENT_WEIGHTS）で足し合わせる。重みの合計は1。
#   ジャカード係数 = 重なりの数 ÷（自分の数 + 相手の数 − 重なりの数）。自分の数・相手の数は、推薦の集計の項目数（PR286）。
#   重なりの数は、タグの表どうしを結合して数える。重なりがある組だけが出てくるので、相手のタグをすべて読まずに済む。
#   どちらかが未入力の項目は0点（分母は常に重みの合計の1）。
#   推薦の集計の行がない学生・募集は、項目数が分からないので、結果に出さない（行は順12 の処理ですべて作られる）。
#
# Django でいえば、annotate() では書ききれないので raw() で SQL を直接書くのにあたる
module Recommendation
  class Content
    # 1組の結果。left_id・right_id は、呼んだときの左・右の集まりの番号
    Row = Data.define(:left_id, :right_id, :content)

    # 募集の側の表の名前
    POSTING = {
      model: JobPosting,
      table: "job_postings",
      stats_table: "job_posting_recommendation_stats",
      key: "job_posting_id",
      job_categories: "job_posting_job_categories",
      work_processes: "job_posting_work_processes",
      technologies: "job_posting_technologies",
      industries: "job_posting_industries",
      culture_prefix: "culture"
    }.freeze

    # 学生の側の表の名前。技術はプログラミング歴（「その他」の行は技術が空なので、結合で自然に外れる）
    STUDENT = {
      model: StudentProfile,
      table: "student_profiles",
      stats_table: "student_recommendation_stats",
      key: "student_profile_id",
      job_categories: "student_interested_job_categories",
      technologies: "student_skills",
      industries: "student_interested_industries",
      culture_prefix: "personality"
    }.freeze

    # 募集×学生。job_postings・students は、Rails の問い合わせ（JobPosting.published など）か番号の配列。
    # top を渡すと、近さの高い順にその件数だけ返す（学生検索の「内容の経路」の上位1,000人など）
    def self.posting_student(job_postings, students, top: nil)
      new(:posting_student, POSTING, STUDENT, job_postings, students).rows(top: top)
    end

    # 学生どうし（スカウト後のポップアップ、リランキングの U）
    def self.student_student(students, other_students, top: nil)
      new(:student_student, STUDENT, STUDENT, students, other_students).rows(top: top)
    end

    # 募集どうし（応募完了のポップアップ、通知、リランキングの I）
    def self.posting_posting(job_postings, other_job_postings, top: nil)
      new(:posting_posting, POSTING, POSTING, job_postings, other_job_postings).rows(top: top)
    end

    def initialize(pair, left, right, left_set, right_set)
      @pair = pair
      @left = left
      @right = right
      @left_ids_sql = ids_sql(left, left_set)
      @right_ids_sql = ids_sql(right, right_set)
      @weights = Parameters::CONTENT_WEIGHTS.fetch(pair)
    end

    # 計算して、Row の配列で返す
    def rows(top: nil)
      result = ActiveRecord::Base.connection.select_all(sql(top), "Recommendation::Content")
      result.rows.map { |left_id, right_id, content| Row.new(left_id.to_i, right_id.to_i, content.to_f) }
    end

    private

    # 集まりを「番号を返す SQL」にする。問い合わせならそのまま番号だけを選び直し、配列なら番号で絞る問い合わせにする
    def ids_sql(side, set)
      relation = set.is_a?(ActiveRecord::Relation) ? set : side[:model].where(id: Array(set))
      relation.reselect(:id).to_sql
    end

    def sql(top)
      <<~SQL
        WITH
          lefts AS (#{@left_ids_sql}),
          rights AS (#{@right_ids_sql}),
          #{common_sql("middle_common", :job_categories, "job_middle_category_id")},
          #{majors_sql("left_majors", @left, "lefts")},
          #{majors_sql("right_majors", @right, "rights")},
          major_common AS (
            SELECT l.owner_id AS left_id, r.owner_id AS right_id, COUNT(*) AS n
            FROM left_majors l
            JOIN right_majors r ON r.major_id = l.major_id
            GROUP BY l.owner_id, r.owner_id
          ),
          #{common_sql("technology_common", :technologies, "technology_id")},
          #{common_sql("industry_common", :industries, "industry_id")}
          #{", #{common_sql("work_process_common", :work_processes, "work_process_id")}" if work_process?}
        SELECT lt.id AS left_id, rt.id AS right_id, (#{score_sql}) AS content
        FROM #{@left[:table]} lt
        JOIN #{@left[:stats_table]} ls ON ls.#{@left[:key]} = lt.id
        CROSS JOIN #{@right[:table]} rt
        JOIN #{@right[:stats_table]} rs ON rs.#{@right[:key]} = rt.id
        LEFT JOIN middle_common mc ON mc.left_id = lt.id AND mc.right_id = rt.id
        LEFT JOIN major_common jc ON jc.left_id = lt.id AND jc.right_id = rt.id
        LEFT JOIN technology_common tc ON tc.left_id = lt.id AND tc.right_id = rt.id
        LEFT JOIN industry_common ic ON ic.left_id = lt.id AND ic.right_id = rt.id
        #{'LEFT JOIN work_process_common pc ON pc.left_id = lt.id AND pc.right_id = rt.id' if work_process?}
        WHERE lt.id IN (SELECT id FROM lefts) AND rt.id IN (SELECT id FROM rights)
        #{"ORDER BY content DESC, left_id, right_id LIMIT #{Integer(top)}" if top}
      SQL
    end

    # 工程は募集どうしのときだけ使う
    def work_process?
      @weights.key?(:work_process)
    end

    # 組ごとの、タグの重なりの数。左の表と右の表を、タグの番号が同じ行どうしで結合して数える
    def common_sql(name, tag_table, tag_column)
      <<~SQL
        #{name} AS (
          SELECT l.#{@left[:key]} AS left_id, r.#{@right[:key]} AS right_id, COUNT(*) AS n
          FROM #{@left.fetch(tag_table)} l
          JOIN #{@right.fetch(tag_table)} r ON r.#{tag_column} = l.#{tag_column}
          WHERE l.#{@left[:key]} IN (SELECT id FROM lefts) AND r.#{@right[:key]} IN (SELECT id FROM rights)
          GROUP BY l.#{@left[:key]}, r.#{@right[:key]}
        )
      SQL
    end

    # 片側の「持ち主ごとの大分類の一覧（重複なし）」。職種の中分類から、中分類の表を通して大分類を取る
    def majors_sql(name, side, ids_name)
      <<~SQL
        #{name} AS (
          SELECT DISTINCT t.#{side[:key]} AS owner_id, m.job_major_category_id AS major_id
          FROM #{side[:job_categories]} t
          JOIN job_middle_categories m ON m.id = t.job_middle_category_id
          WHERE t.#{side[:key]} IN (SELECT id FROM #{ids_name})
        )
      SQL
    end

    # 項目ごとの点に重みをかけて足したもの
    def score_sql
      @weights.map { |item, weight| "#{quote(weight)} * (#{item_score_sql(item)})" }.join(" + ")
    end

    def item_score_sql(item)
      case item
      when :job_category
        # 中分類が1つでも重なれば中分類のジャカード係数、重ならなければ大分類のジャカード係数 × 0.5
        "CASE WHEN COALESCE(mc.n, 0) > 0 THEN #{jaccard_sql('mc', 'job_middle_category_count')} " \
          "ELSE #{quote(Parameters::JOB_MAJOR_FALLBACK)} * #{jaccard_sql('jc', 'job_major_category_count')} END"
      when :work_process
        jaccard_sql("pc", "work_process_count")
      when :technology
        # 募集×学生は「募集の使用技術のうち、学生が持っている割合」。学生が募集にない技術を持っていても下がらない。
        # 募集に技術が1つもなければ、未入力として0点
        if @pair == :posting_student
          "COALESCE(COALESCE(tc.n, 0)::float / NULLIF(ls.technology_count, 0), 0)"
        else
          jaccard_sql("tc", "technology_count")
        end
      when :industry
        jaccard_sql("ic", "industry_count")
      when :culture
        culture_sql
      end
    end

    # ジャカード係数。両方とも0件（分母が0）なら0点
    def jaccard_sql(common, count_column)
      overlap = "COALESCE(#{common}.n, 0)"
      "COALESCE(#{overlap}::float / NULLIF(ls.#{count_column} + rs.#{count_column} - #{overlap}, 0), 0)"
    end

    # カルチャー・性格：5軸それぞれ 1 −（差 ÷ 幅）の平均。幅は5軸の範囲（−2〜2 なら4）。
    # 軸の一覧と範囲は concerns/culture_axes.rb の1か所から取る。中央も普通の値として扱う（7-2）
    def culture_sql
      width = CultureAxes::MAX - CultureAxes::MIN
      terms = CultureAxes::AXES.map do |axis|
        "(1 - ABS(lt.#{@left[:culture_prefix]}_#{axis} - rt.#{@right[:culture_prefix]}_#{axis})::float / #{width})"
      end
      "(#{terms.join(' + ')}) / #{CultureAxes::AXES.size}"
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end
  end
end
