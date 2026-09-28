# 募集どうし・学生どうしの近さ f（design/designs/処理設計_類似度.md の 7-2「募集どうし・学生どうしの近さ」）。
#
#   f(P_i, P_j) = (1 − w_P) × Content(P_i, P_j) + w_P × CF_P(P_i, P_j)、w_P = w_max^P × c(min(|B(P_i)|, |B(P_j)|))
#   f(S_i, S_j) = (1 − w_S) × Content(S_i, S_j) + w_S × CF_S(S_i, S_j)、w_S = w_max^S × c(min(|A(S_i)|, |A(S_j)|))
#   c(n) = n ÷ (n + λ)。行動データが少ないうちは内容を重視し、増えるほど行動を重視する
#
# 内容の近さ（Recommendation::Content）と行動の近さ（Recommendation::Behavior）の SQL を1本につなぎ、
# 混ぜ合わせまでデータベースで行う（PR316）。似たもののポップアップでは相手が10万人になるので、
# 全員の近さを Rails に読み込まずに、並べ替えと「上から5件」までデータベースに任せるため。
# 使う場面：応募完了のポップアップと通知（募集どうし。順14・15）、スカウト後のポップアップ（学生どうし。順14）、
# 募集×学生の f の I と U（13-3）。自分自身との組を除くかどうかは、呼ぶ側が決める
module Recommendation
  class Similarity
    # 1組の結果。f はその組の近さ（0〜1）
    Row = Data.define(:left_id, :right_id, :f)

    def self.posting_posting(job_postings, other_job_postings)
      rows(posting_posting_sql(job_postings, other_job_postings))
    end

    def self.student_student(students, other_students)
      rows(student_student_sql(students, other_students))
    end

    # 募集どうしの f を出す SQL を、実行せずに文字列で返す（列は left_id・right_id・f）。
    # 似た募集のポップアップが、この SQL を部品として組み込み、並べ替えと件数の絞り込みを足す
    def self.posting_posting_sql(job_postings, other_job_postings)
      combine_sql(
        Content.posting_posting_sql(job_postings, other_job_postings),
        Behavior.posting_posting_sql(job_postings, other_job_postings),
        "job_posting_recommendation_stats", "job_posting_id", Parameters::BEHAVIOR_WEIGHT_MAX.fetch(:posting)
      )
    end

    # 学生どうしの版（似た学生のポップアップが使う）
    def self.student_student_sql(students, other_students)
      combine_sql(
        Content.student_student_sql(students, other_students),
        Behavior.student_student_sql(students, other_students),
        "student_recommendation_stats", "student_profile_id", Parameters::BEHAVIOR_WEIGHT_MAX.fetch(:student)
      )
    end

    # データ量に応じた信頼度 c(n) = n ÷ (n + λ)。件数0なら0で、行動の重みがなくなる。
    # 募集×学生の f の重み（w_I・w_U。13-3）で使う。学生どうし・募集どうしの重みは、同じ式を combine_sql の中に SQL で書いている
    def self.confidence(count)
      count.to_f / (count + Parameters::CONFIDENCE_LAMBDA)
    end

    # 内容の近さの組すべてに、行動の近さ（共起がない組は CF = 0）を重みで混ぜる SQL。
    # 行動の近さは共起がある組だけなので、LEFT JOIN で内容の近さの組をすべて残す。
    # 重みに使う件数（interest_count）は、左右の推薦の集計から読む（内容の近さは集計の行がある組だけなので、JOIN で落ちない）
    def self.combine_sql(content_sql, behavior_sql, stats_table, key, weight_max)
      count = "LEAST(ls.interest_count, rs.interest_count)"
      # c(n) = n ÷ (n + λ)。Ruby の confidence と同じ式
      weight = "#{quote(weight_max)} * #{count}::double precision / (#{count} + #{quote(Parameters::CONFIDENCE_LAMBDA)})"
      <<~SQL
        WITH
          contents AS (#{content_sql}),
          behaviors AS (#{behavior_sql})
        SELECT c.left_id, c.right_id,
               (1 - (#{weight})) * c.content + (#{weight}) * COALESCE(b.cf, 0) AS f
        FROM contents c
        LEFT JOIN behaviors b ON b.left_id = c.left_id AND b.right_id = c.right_id
        JOIN #{stats_table} ls ON ls.#{key} = c.left_id
        JOIN #{stats_table} rs ON rs.#{key} = c.right_id
      SQL
    end

    def self.rows(sql)
      result = ActiveRecord::Base.connection.select_all(sql, "Recommendation::Similarity")
      result.rows.map { |left_id, right_id, f| Row.new(left_id.to_i, right_id.to_i, f.to_f) }
    end

    def self.quote(value)
      ActiveRecord::Base.connection.quote(value)
    end

    private_class_method :combine_sql, :rows, :quote
  end
end
