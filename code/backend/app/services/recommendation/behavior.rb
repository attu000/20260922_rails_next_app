# 行動の近さ（design/designs/処理設計_類似度.md の 7-2「共通の部品」「行動から見た近さ」）。
# 使う行動は、学生自身の意思表示（応募・スカウトへのマッチと、そのときの応募理由）だけ。見送り・不合格は使わない。
#
#   割り引きの重み  u(S) = 1 / log(1 + |A(S)|)、u(P) = 1 / log(1 + |B(P)|)   … 件数は推薦の集計（上限なし）
#   応募理由の近さ  g(r_i, r_j) = β + (1 − β) × |r_i ∧ r_j| ÷ |r_i ∨ r_j|     … reason_mask のビットで数える
#   共起           Co_P(P_i, P_j) = 両方に興味を示した学生 S の u(S) の合計
#                  Co_S(S_i, S_j) = 両方が興味を示した募集 P の u(P) × g の合計
#   CF             Co ÷ √(自分の self_weight × 相手の self_weight)。0〜1
#
# 共起は、左の集まりの側からたどって数える（計算に使う興味の数の上限をかけるので、どちら側から数えたかで値がわずかに
# 変わることがある。7-2 の既知の性質）。左には「今見ている募集・学生」を渡す。
# 共起が0より大きい組だけを返す。ない組の CF は0として扱う（Recommendation::Similarity）。
# 推薦の集計の行がない相手は、結果に出さない（Recommendation::Content と同じ）
module Recommendation
  class Behavior
    # 1組の結果
    Row = Data.define(:left_id, :right_id, :co, :cf)

    # reason_mask の桁数（応募理由の番号の最大 + 1。今は12個で12桁）
    REASON_BITS = CandidacyReason.reasons.values.max + 1

    def self.posting_posting(job_postings, other_job_postings)
      rows(posting_posting_sql(job_postings, other_job_postings))
    end

    def self.student_student(students, other_students)
      rows(student_student_sql(students, other_students))
    end

    # 募集どうし：左の募集 → 興味を示した学生（L_P 人まで）→ その学生が興味を示した募集（L_S 件まで）のうち右の集まりのもの。
    # 実行せずに SQL の文字列で返す（列は left_id・right_id・co・cf）。内容の近さと混ぜて f まで SQL で出すときの部品（PR316）
    def self.posting_posting_sql(job_postings, other_job_postings)
      lefts = ids_sql(JobPosting, job_postings)
      rights = ids_sql(JobPosting, other_job_postings)
      <<~SQL
        WITH
          left_interests AS (#{Interests.of_postings_sql(lefts)}),
          bridge_interests AS (#{Interests.of_students_sql('SELECT DISTINCT student_profile_id FROM left_interests')}),
          co AS (
            SELECT li.job_posting_id AS left_id, bi.job_posting_id AS right_id,
                   SUM(#{discount_sql('ss')}) AS co
            FROM left_interests li
            JOIN bridge_interests bi ON bi.student_profile_id = li.student_profile_id
            JOIN student_recommendation_stats ss ON ss.student_profile_id = li.student_profile_id
            WHERE bi.job_posting_id IN (#{rights})
            GROUP BY li.job_posting_id, bi.job_posting_id
          )
        SELECT co.left_id, co.right_id, co.co, #{cf_sql} AS cf
        FROM co
        JOIN job_posting_recommendation_stats ls ON ls.job_posting_id = co.left_id
        JOIN job_posting_recommendation_stats rs ON rs.job_posting_id = co.right_id
      SQL
    end

    # 学生どうし：左の学生 → 興味を示した募集（L_S 件まで）→ その募集に興味を示した学生（L_P 人まで）のうち右の集まりのもの。
    # 実行せずに SQL の文字列で返す（募集どうしと同じ形）
    def self.student_student_sql(students, other_students)
      lefts = ids_sql(StudentProfile, students)
      rights = ids_sql(StudentProfile, other_students)
      <<~SQL
        WITH
          left_interests AS (#{Interests.of_students_sql(lefts)}),
          bridge_interests AS (#{Interests.of_postings_sql('SELECT DISTINCT job_posting_id FROM left_interests')}),
          co AS (
            SELECT li.student_profile_id AS left_id, bi.student_profile_id AS right_id,
                   SUM(#{discount_sql('ps')} * #{reason_similarity_sql('li.reason_mask', 'bi.reason_mask')}) AS co
            FROM left_interests li
            JOIN bridge_interests bi ON bi.job_posting_id = li.job_posting_id
            JOIN job_posting_recommendation_stats ps ON ps.job_posting_id = li.job_posting_id
            WHERE bi.student_profile_id IN (#{rights})
            GROUP BY li.student_profile_id, bi.student_profile_id
          )
        SELECT co.left_id, co.right_id, co.co, #{cf_sql} AS cf
        FROM co
        JOIN student_recommendation_stats ls ON ls.student_profile_id = co.left_id
        JOIN student_recommendation_stats rs ON rs.student_profile_id = co.right_id
      SQL
    end

    # 割り引きの重み u = 1 / log(1 + 件数)。stats はその人・募集の推薦の集計の表の別名。
    # ジョブが数え直すまでの数秒間は、件数が0のままのことがあるので、少なくとも1として数える（log(1) = 0 で割らないため）
    def self.discount_sql(stats)
      "1 / LN(1 + GREATEST(#{stats}.interest_count, 1)::double precision)"
    end

    # 応募理由の近さ g。reason_mask の「両方で立っているビットの数 ÷ どちらかで立っているビットの数」。
    # 応募理由は最低1つ必須なので、分母は0にならない
    def self.reason_similarity_sql(left_mask, right_mask)
      both = "bit_count((#{left_mask} & #{right_mask})::integer::bit(#{REASON_BITS}))"
      either = "bit_count((#{left_mask} | #{right_mask})::integer::bit(#{REASON_BITS}))"
      base = ActiveRecord::Base.connection.quote(Parameters::REASON_BASE)
      "(#{base} + (1 - #{base}) * #{both}::double precision / #{either})"
    end

    # CF = 共起 ÷ √(左の self_weight × 右の self_weight)。ls・rs は左右の推薦の集計の表の別名。
    # ジョブが数え直すまでの数秒間は self_weight が古いことがあるので、0で割らず、1を超えないようにする
    def self.cf_sql
      "LEAST(COALESCE(co.co / NULLIF(SQRT(ls.self_weight * rs.self_weight), 0), 0), 1)"
    end

    def self.rows(sql)
      result = ActiveRecord::Base.connection.select_all(sql, "Recommendation::Behavior")
      result.rows.map { |left_id, right_id, co, cf| Row.new(left_id.to_i, right_id.to_i, co.to_f, cf.to_f) }
    end

    # 集まりを「番号を返す SQL」にする（Recommendation::Content と同じ受け取り方。問い合わせか番号の配列）
    def self.ids_sql(model, set)
      relation = set.is_a?(ActiveRecord::Relation) ? set : model.where(id: Array(set))
      relation.reselect(:id).to_sql
    end

    private_class_method :discount_sql, :reason_similarity_sql, :cf_sql, :rows, :ids_sql
  end
end
