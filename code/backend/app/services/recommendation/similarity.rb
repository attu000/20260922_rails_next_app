# 募集どうし・学生どうしの近さ f（design/designs/処理設計_類似度.md の 7-2「募集どうし・学生どうしの近さ」）。
#
#   f(P_i, P_j) = (1 − w_P) × Content(P_i, P_j) + w_P × CF_P(P_i, P_j)、w_P = w_max^P × c(min(|B(P_i)|, |B(P_j)|))
#   f(S_i, S_j) = (1 − w_S) × Content(S_i, S_j) + w_S × CF_S(S_i, S_j)、w_S = w_max^S × c(min(|A(S_i)|, |A(S_j)|))
#   c(n) = n ÷ (n + λ)。行動データが少ないうちは内容を重視し、増えるほど行動を重視する
#
# 内容の近さ（Recommendation::Content）と行動の近さ（Recommendation::Behavior）はデータベースで計算し、
# 混ぜ合わせ（組ごとの掛け算と足し算）だけを Ruby で行う（式を読みやすく保つため）。
# 使う場面：応募完了のポップアップと通知（募集どうし。順14・15）、スカウト後のポップアップ（学生どうし。順14）、
# 募集×学生の f の I と U（13-3）。自分自身との組を除くかどうかは、呼ぶ側が決める
module Recommendation
  class Similarity
    # 1組の結果。f はその組の近さ（0〜1）
    Row = Data.define(:left_id, :right_id, :f)

    def self.posting_posting(job_postings, other_job_postings)
      combine(
        Content.posting_posting(job_postings, other_job_postings),
        Behavior.posting_posting(job_postings, other_job_postings),
        JobPostingRecommendationStat, :job_posting_id, Parameters::BEHAVIOR_WEIGHT_MAX.fetch(:posting)
      )
    end

    def self.student_student(students, other_students)
      combine(
        Content.student_student(students, other_students),
        Behavior.student_student(students, other_students),
        StudentRecommendationStat, :student_profile_id, Parameters::BEHAVIOR_WEIGHT_MAX.fetch(:student)
      )
    end

    # データ量に応じた信頼度 c(n) = n ÷ (n + λ)。件数0なら0で、行動の重みがなくなる。
    # 募集×学生の f の重み（w_I・w_U。13-3）でも使う
    def self.confidence(count)
      count.to_f / (count + Parameters::CONFIDENCE_LAMBDA)
    end

    # 内容の近さの組すべてに、行動の近さ（共起がない組は CF = 0）を重みで混ぜる。
    # 重みに使う件数（interest_count）は、組に出てくる番号の分だけ、推薦の集計からまとめて読む
    def self.combine(contents, behaviors, stat_model, key, weight_max)
      cf_by_pair = behaviors.to_h { |row| [ [ row.left_id, row.right_id ], row.cf ] }
      ids = contents.flat_map { |row| [ row.left_id, row.right_id ] }.uniq
      counts = stat_model.where(key => ids).pluck(key, :interest_count).to_h

      contents.map do |row|
        count = [ counts.fetch(row.left_id, 0), counts.fetch(row.right_id, 0) ].min
        weight = weight_max * confidence(count)
        cf = cf_by_pair.fetch([ row.left_id, row.right_id ], 0.0)
        Row.new(row.left_id, row.right_id, (1 - weight) * row.content + weight * cf)
      end
    end
    private_class_method :combine
  end
end
