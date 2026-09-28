# 計算に使う興味の一覧（design/designs/処理設計_類似度.md の 7-2「計算に使う興味の数の上限」。PR287）。
# 人気の募集（応募者が多い）や、大量に応募する学生がいても、1回の計算量が一定を超えないように、
# 興味を示した日時の新しい順に、募集ごとに L_P 人・学生ごとに L_S 件までに絞る。応募の数そのものは制限しない。
# 使う場所：共起の値の集計（Recommendation::Behavior）、I・U・1次検索の点の平均と候補の集め方（13-3）。
# 件数（interest_count）と self_weight（順12）は、ここを使わずに全員分で数える
module Recommendation
  module Interests
    # 興味を示した日時。応募は応募した日時、スカウトはマッチした日時（議事録23 の 3-4）。
    # 応募より前に届いていたスカウトでも、あとで応じてマッチすれば、その時点の新しい興味になる
    INTEREST_AT_SQL = <<~SQL.squish.freeze
      CASE WHEN candidacies.origin = #{Candidacy.origins.fetch('application')}
        THEN candidacies.created_at ELSE candidacies.matched_at END
    SQL

    # 渡された募集それぞれについて、興味を示したやりとりを新しい順に L_P 件まで返す SQL。
    # job_posting_ids_sql：募集の番号を返す SQL（サブクエリとして IN の中に入れる）。
    # 返す列：job_posting_id、student_profile_id、reason_mask
    def self.of_postings_sql(job_posting_ids_sql)
      ranked_sql(:job_posting_id, job_posting_ids_sql, Parameters::INTERESTS_PER_POSTING)
    end

    # 渡された学生それぞれについて、興味を示したやりとりを新しい順に L_S 件まで返す SQL。返す列は上と同じ
    def self.of_students_sql(student_ids_sql)
      ranked_sql(:student_profile_id, student_ids_sql, Parameters::INTERESTS_PER_STUDENT)
    end

    # 学生ごとに、計算に使う興味（新しい順に L_S 件まで）の募集の番号を返す。
    # 返すもの：{ 学生の番号 => [募集の番号, …] }。興味のない学生は入らない
    def self.postings_by_student(student_ids)
      rows = pair_rows(of_students_sql(StudentProfile.where(id: Array(student_ids)).select(:id).to_sql))
      rows.group_by { |_job_posting_id, student_id| student_id }
          .transform_values { |pairs| pairs.map { |job_posting_id, _student_id| job_posting_id } }
    end

    # 募集ごとに、計算に使う興味（新しい順に L_P 人まで）の学生の番号を返す。
    # 返すもの：{ 募集の番号 => [学生の番号, …] }。興味のない募集は入らない
    def self.students_by_posting(job_posting_ids)
      rows = pair_rows(of_postings_sql(JobPosting.where(id: Array(job_posting_ids)).select(:id).to_sql))
      rows.group_by { |job_posting_id, _student_id| job_posting_id }
          .transform_values { |pairs| pairs.map { |_job_posting_id, student_id| student_id } }
    end

    # SQL を実行して [募集の番号, 学生の番号] の一覧にする
    def self.pair_rows(sql)
      ActiveRecord::Base.connection.select_rows(sql, "Recommendation::Interests")
                        .map { |job_posting_id, student_id, _reason_mask| [ job_posting_id.to_i, student_id.to_i ] }
    end
    private_class_method :pair_rows

    # 持ち主（募集か学生）ごとに、新しい順の順位を付け、順位が limit 以下の行だけを残す。
    # ROW_NUMBER() OVER (PARTITION BY …) は、グループごとに1から順位を付ける関数
    # （Django の Window(expression=RowNumber(), partition_by=…, order_by=…) にあたる）。
    # 「興味」の決まり（応募理由・マッチ理由が付いたやりとり）は Candidacy.interests の1か所から使う
    def self.ranked_sql(owner_column, ids_sql, limit)
      ranked = Candidacy.interests
                        .where("candidacies.#{owner_column} IN (#{ids_sql})")
                        .select(
                          :job_posting_id, :student_profile_id, :reason_mask,
                          Arel.sql("ROW_NUMBER() OVER (PARTITION BY candidacies.#{owner_column} " \
                                   "ORDER BY #{INTEREST_AT_SQL} DESC, candidacies.id DESC) AS interest_rank")
                        )
      <<~SQL
        SELECT ranked.job_posting_id, ranked.student_profile_id, ranked.reason_mask
        FROM (#{ranked.to_sql}) ranked
        WHERE ranked.interest_rank <= #{Integer(limit)}
      SQL
    end
    private_class_method :ranked_sql
  end
end
