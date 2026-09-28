# 企業の募集にとっての、学生のおすすめ順（design/designs/処理設計_類似度.md の 7-5「C5 学生検索の『○○募集におすすめ順』」）。
# 推薦の計算は、画面や API から切り離したこの部品にまとめる（技術構成.md の 9-4）。募集検索の JobPostingRecommender と同じ形。
#
# 返すのは、群（条件に合う・合わない）ごとの上位 R 人の番号を、f(P, S) の高い順に並べたものだけ。
# 101人目以降の並び（最終活動が新しい順）とページ分けは、検索の本体がデータベースで行う（PR295）。
# 学生は10万人と多いので、1次検索の候補を内容と行動の2つの経路から集め、その候補だけ F1 を計算する（PR282）。
#
# 工程の区切りに、計測用の印（instrument）を付けている（PR307。JobPostingRecommender と同じ）
class StudentRecommender
  # job_posting：基準にする募集。groups：群ごとの学生の問い合わせ（[条件に合う学生, 合わない学生]）。
  # 返すもの：[合う群の上位の番号…, 合わない群の上位の番号…]（群の順番は渡された順のまま）
  def self.ranked_ids(job_posting, groups)
    parameters = Recommendation::Parameters

    cf_by_posting, behavior_students, posting_count = instrument("first_pass") do |payload|
      # 手順2（群に共通）：P の学生たち → その学生たちの募集 P_k とたどり、CF(P, P_k) を出す。P 自身は除く
      cf_by_posting = Recommendation::Behavior.posting_posting([ job_posting.id ], JobPosting.all)
                                              .reject { |row| row.right_id == job_posting.id }
                                              .to_h { |row| [ row.right_id, row.cf ] }

      # 手順3（群に共通）：CF の高い上位 K_B 件の募集に興味を示した学生（行動の経路）。
      # 上限を超えるときは、CF の高い募集の学生から順に残す
      behavior_postings = cf_by_posting.sort_by { |id, cf| [ -cf, -id ] }.first(parameters::BEHAVIOR_ROUTE_POSTINGS).map(&:first)
      students_by_posting = Recommendation::Interests.students_by_posting(behavior_postings)
      behavior_students = behavior_postings.flat_map { |id| students_by_posting.fetch(id, []) }
                                           .uniq.first(parameters::BEHAVIOR_ROUTE_MAX_STUDENTS)
      payload[:rows] = cf_by_posting.size

      [ cf_by_posting, behavior_students, JobPostingRecommendationStat.where(job_posting_id: job_posting.id).pick(:interest_count) || 0 ]
    end

    groups.flat_map do |group|
      contents = instrument("content") do |payload|
        candidate_contents(job_posting, group, behavior_students).tap { |rows| payload[:rows] = rows.size }
      end

      top_ids = instrument("first_pass") do
        interests = Recommendation::Interests.postings_by_student(contents.keys)
        student_counts = StudentRecommendationStat.where(student_profile_id: contents.keys).pluck(:student_profile_id, :interest_count).to_h

        # 手順4：F1 = w_C × Content + (w_I + w_U) × Ĩ。Ĩ は学生の興味の募集たち（P 自身を除く）と P の CF の平均（手順2の値）
        first_pass = contents.to_h do |student_id, content|
          others = interests.fetch(student_id, []) - [ job_posting.id ]
          tilde = others.empty? ? 0.0 : others.sum { |other| cf_by_posting.fetch(other, 0.0) } / others.size
          weight_c, weight_i, weight_u = Recommendation::PostingStudent.weights(student_counts.fetch(student_id, 0), posting_count)
          [ student_id, weight_c * content + (weight_i + weight_u) * tilde ]
        end
        # 同じ点なら番号の大きい順。境目で同じ点が並んでも、毎回同じ結果にするため
        first_pass.sort_by { |id, score| [ -score, -id ] }.first(parameters::RERANK_SIZE).map(&:first)
      end

      # 手順5・6：選んだ学生の f(P, S) を出し、高い順に並べる。同じ点なら最終活動の新しい順 → 番号の大きい順
      instrument("rerank") do
        scores = Recommendation::PostingStudent.for_posting(job_posting, top_ids, contents)
        last_active_on = StudentProfile.joins(:user).where(id: top_ids).pluck(:id, "users.last_active_on").to_h
        top_ids.sort_by { |id| [ -scores.fetch(id), -(last_active_on[id]&.jd || 0), -id ] }
      end
    end
  end

  # 1つの群の候補と、その内容の近さ。{ 学生の番号 => Content(P, S) }
  #   手順1：群のすべての学生のうち、内容の近さの上位 N_C 人（内容の経路）
  #   行動の経路の学生のうち、この群にいて、まだ入っていない学生は、ここで内容の近さを出して足す
  def self.candidate_contents(job_posting, group, behavior_students)
    contents = Recommendation::Content.posting_student([ job_posting.id ], group, top: Recommendation::Parameters::CONTENT_ROUTE_SIZE)
                                      .to_h { |row| [ row.right_id, row.content ] }
    extra_ids = group.where(id: behavior_students).pluck(:id) - contents.keys
    return contents if extra_ids.empty?

    contents.merge(Recommendation::Content.posting_student([ job_posting.id ], extra_ids).to_h { |row| [ row.right_id, row.content ] })
  end
  private_class_method :candidate_contents

  # 工程の区切りの印（PR307）。name は content（内容の近さ）・first_pass（行動の近さと 1次検索の点 F1）・
  # rerank（上位 R 人を f(P, S) で並べ直す）。ブロックの値をそのまま返す
  def self.instrument(name, &block)
    ActiveSupport::Notifications.instrument("#{name}.recommendation", &block)
  end
  private_class_method :instrument
end
