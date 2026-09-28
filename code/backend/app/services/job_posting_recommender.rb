# 学生にとっての、募集のおすすめ順（design/designs/処理設計_類似度.md の 7-5「S2 募集一覧のおすすめ順」）。
# 推薦の計算は、画面や API から切り離したこの部品にまとめる（技術構成.md の 9-4）。
#
# 返すのは、群（条件に合う・合わない）ごとの上位 R 件の番号を、f(P, S) の高い順に並べたものだけ。
# 101件目以降の並び（新着順）とページ分けは、検索の本体がデータベースで行う（PR295）。
# 募集は1万件なので、候補を絞らずに、群のすべての募集の1次検索の点 F1 を計算する
class JobPostingRecommender
  # student：検索している学生。groups：群ごとの募集の問い合わせ（[条件に合う募集, 合わない募集]）。
  # 返すもの：[合う群の上位の番号…, 合わない群の上位の番号…]（群の順番は渡された順のまま）
  def self.ranked_ids(student, groups)
    # 手順2（群に共通）：S の興味の募集 P_k → その学生たち → その学生たちの募集 P とたどり、組 (P_k, P) の CF を出す
    interested = Recommendation::Interests.postings_by_student([ student.id ]).fetch(student.id, [])
    cf_by_pair = Recommendation::Behavior.posting_posting(interested, JobPosting.all)
                                         .to_h { |row| [ [ row.left_id, row.right_id ], row.cf ] }
    student_count = StudentRecommendationStat.where(student_profile_id: student.id).pick(:interest_count) || 0

    groups.flat_map do |group|
      # 手順1：群のすべての募集の、内容の近さ
      contents = Recommendation::Content.posting_student(group, [ student.id ]).to_h { |row| [ row.left_id, row.content ] }
      posting_counts = JobPostingRecommendationStat.where(job_posting_id: group.reselect(:id)).pluck(:job_posting_id, :interest_count).to_h

      # 手順3：F1 = w_C × Content + (w_I + w_U) × Ĩ。Ĩ は S の興味の募集たち（P 自身を除く）と P の CF の平均
      first_pass = contents.to_h do |job_posting_id, content|
        others = interested - [ job_posting_id ]
        tilde = others.empty? ? 0.0 : others.sum { |other| cf_by_pair.fetch([ other, job_posting_id ], 0.0) } / others.size
        weight_c, weight_i, weight_u = Recommendation::PostingStudent.weights(student_count, posting_counts.fetch(job_posting_id, 0))
        [ job_posting_id, weight_c * content + (weight_i + weight_u) * tilde ]
      end
      # 同じ点なら番号の大きい順。境目で同じ点が並んでも、毎回同じ結果にするため
      top_ids = first_pass.sort_by { |id, score| [ -score, -id ] }.first(Recommendation::Parameters::RERANK_SIZE).map(&:first)

      # 手順4・5：選んだ募集の f(P, S) を出し、高い順に並べる。同じ点なら新着順（最初に掲載した日時 → 番号の大きい順）
      scores = Recommendation::PostingStudent.for_student(student, top_ids, contents)
      published_at = JobPosting.where(id: top_ids).pluck(:id, :published_at).to_h
      top_ids.sort_by { |id| [ -scores.fetch(id), -published_at[id].to_f, -id ] }
    end
  end
end
