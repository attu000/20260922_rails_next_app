# 学生が募集に興味を示したあと（応募・スカウトへのマッチ）に、裏側で動くジョブ（処理設計_類似度.md の 7-5「応募・マッチ時の手順」）。
# 呼ぶのは Candidacy.apply と Candidacy#match_by_student の2か所だけ（技術構成.md の 9-1-1 の4）。
# 企業のマッチ・見送り・合格・不合格・スカウトの送信では呼ばない（7-5 の「更新しない出来事」）。
#
# 学生 S が募集 Z に興味を示すと、|A(S)| と |B(Z)| が変わり、それを使う u(S)・u(Z) も変わる。
# そのため、Z に興味を示した学生全員の W と、S が興味を示した募集全部の W を、元データから数え直す（PR276）。
# 何度実行しても同じ結果になるので、失敗して再実行されても、二重に積まれても値はずれない。
# 【強み】の順15 で、ここに「Z に似た募集を持つ企業への通知」を足す（PR272）
class InterestRecordedJob < ApplicationJob
  # 推薦用の専用の待ち行列。1つずつ順番に実行する設定は config/queue.yml（7-5 の基本方針）
  queue_as :recommendation

  # candidacy：興味が記録されたやりとり（Active Job が番号に変えて待ち行列に入れ、実行するときに取り出し直す）
  def perform(candidacy)
    # Z に興味を示した学生全員（S 自身を含む）
    student_ids = Candidacy.interests.where(job_posting_id: candidacy.job_posting_id).pluck(:student_profile_id)
    # S が興味を示した募集全部（Z 自身を含む）
    job_posting_ids = Candidacy.interests.where(student_profile_id: candidacy.student_profile_id).pluck(:job_posting_id)

    # 件数と self_weight を一緒に数え直す。S と Z の件数（7-5 の手順1）も、この中に含まれる
    StudentRecommendationStat.refresh_interests!(student_ids)
    JobPostingRecommendationStat.refresh_interests!(job_posting_ids)
  end
end
