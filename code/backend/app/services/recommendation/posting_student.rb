# 募集と学生のおすすめ度 f(P, S)（design/designs/処理設計_類似度.md の 7-2「募集と学生のおすすめ度（推薦の本体）」）。
#
#   f(P, S) = w_C × Content(P, S) + w_I × I(P, S) + w_U × U(P, S)
#   I(P, S) … 学生 S が興味を示した募集たち（P 自身は除く。L_S 件まで）と P の近さ f(P, P_k) のべき平均
#   U(P, S) … 募集 P に興味を示した学生たち（S 自身は除く。L_P 人まで）と S の近さ f(S, S_k) のべき平均
#   w_I = γ × c(|A(S)|)、w_U = γ × c(|B(P)|)、w_C = 1 − w_I − w_U
#   除いたあとの集まりが空なら、その値は0（件数0なら重みも0になる）
#
# リランキング（群ごとの上位100件の並べ直し。7-5）で使う。向きは2つ
#   for_student：学生1人から見た募集たち（募集一覧のおすすめ順）
#   for_posting：募集1件から見た学生たち（学生検索の「○○募集におすすめ順」）
# どちらも「1人（1件）× 多数」にして、必要な近さを1回の問い合わせでまとめて計算する。
# 内容の近さは、呼ぶ側が1次検索で計算済みのものを受け取る（同じ組を2回計算しないため）
module Recommendation
  class PostingStudent
    # 学生1人から見た、募集たちの f(P, S)。
    # contents：{ 募集の番号 => Content(P, S) }。返すもの：{ 募集の番号 => f }
    def self.for_student(student, job_posting_ids, contents)
      job_posting_ids = Array(job_posting_ids).uniq
      return {} if job_posting_ids.empty?

      interested_postings = Interests.postings_by_student([ student.id ]).fetch(student.id, [])
      applicants_by_posting = Interests.students_by_posting(job_posting_ids)

      # I の材料：募集たち × S の興味の募集。U の材料：S × 募集たちの学生の全員
      posting_f = f_by_pair(Similarity.posting_posting(job_posting_ids, interested_postings))
      student_f = f_by_pair(Similarity.student_student([ student.id ], applicants_by_posting.values.flatten.uniq))

      student_count = interest_counts(StudentRecommendationStat, :student_profile_id, [ student.id ]).fetch(student.id, 0)
      posting_counts = interest_counts(JobPostingRecommendationStat, :job_posting_id, job_posting_ids)

      job_posting_ids.to_h do |job_posting_id|
        i = power_mean((interested_postings - [ job_posting_id ]).map { |other| posting_f.fetch([ job_posting_id, other ], 0.0) })
        u = power_mean((applicants_by_posting.fetch(job_posting_id, []) - [ student.id ]).map { |other| student_f.fetch([ student.id, other ], 0.0) })
        f = score(contents.fetch(job_posting_id, 0.0), i, u, student_count, posting_counts.fetch(job_posting_id, 0))
        [ job_posting_id, f ]
      end
    end

    # 募集1件から見た、学生たちの f(P, S)。
    # contents：{ 学生の番号 => Content(P, S) }。返すもの：{ 学生の番号 => f }
    def self.for_posting(job_posting, student_ids, contents)
      student_ids = Array(student_ids).uniq
      return {} if student_ids.empty?

      applicants = Interests.students_by_posting([ job_posting.id ]).fetch(job_posting.id, [])
      postings_by_student = Interests.postings_by_student(student_ids)

      # I の材料：P × 学生たちの興味の募集の全部。U の材料：学生たち × P の学生たち
      posting_f = f_by_pair(Similarity.posting_posting([ job_posting.id ], postings_by_student.values.flatten.uniq))
      student_f = f_by_pair(Similarity.student_student(student_ids, applicants))

      posting_count = interest_counts(JobPostingRecommendationStat, :job_posting_id, [ job_posting.id ]).fetch(job_posting.id, 0)
      student_counts = interest_counts(StudentRecommendationStat, :student_profile_id, student_ids)

      student_ids.to_h do |student_id|
        i = power_mean((postings_by_student.fetch(student_id, []) - [ job_posting.id ]).map { |other| posting_f.fetch([ job_posting.id, other ], 0.0) })
        u = power_mean((applicants - [ student_id ]).map { |other| student_f.fetch([ student_id, other ], 0.0) })
        f = score(contents.fetch(student_id, 0.0), i, u, student_counts.fetch(student_id, 0), posting_count)
        [ student_id, f ]
      end
    end

    # 重み [w_C, w_I, w_U]。学生の件数 |A(S)| と募集の人数 |B(P)| から決める。
    # 1次検索の点 F1（13-3b）でも同じ重みを使う
    def self.weights(student_count, posting_count)
      weight_i = Parameters::NEIGHBOR_WEIGHT_MAX * Similarity.confidence(student_count)
      weight_u = Parameters::NEIGHBOR_WEIGHT_MAX * Similarity.confidence(posting_count)
      [ 1 - weight_i - weight_u, weight_i, weight_u ]
    end

    # べき平均 (Σ x^p ÷ n)^(1/p)。空なら0。p = 1 なら普通の平均
    def self.power_mean(values)
      return 0.0 if values.empty?

      exponent = Parameters::POWER_MEAN_EXPONENT
      (values.sum { |value| value**exponent } / values.size.to_f)**(1.0 / exponent)
    end

    def self.score(content, i, u, student_count, posting_count)
      weight_c, weight_i, weight_u = weights(student_count, posting_count)
      weight_c * content + weight_i * i + weight_u * u
    end

    # Recommendation::Similarity の結果を { [左の番号, 右の番号] => f } にする。
    # 近さが出なかった組（集計の行がないなど）は、呼ぶ側で0として平均に入れる（分母を「興味を示した相手すべて」にそろえるため）
    def self.f_by_pair(rows)
      rows.to_h { |row| [ [ row.left_id, row.right_id ], row.f ] }
    end

    # 推薦の集計から件数を読む。{ 番号 => interest_count }
    def self.interest_counts(stat_model, key, ids)
      stat_model.where(key => ids).pluck(key, :interest_count).to_h
    end

    private_class_method :score, :f_by_pair, :interest_counts
  end
end
