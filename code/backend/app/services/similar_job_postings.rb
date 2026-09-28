# 「この募集に似た募集」を選ぶ（募集詳細の応募完了のポップアップ。㉝）。
# 詳しくは design/designs/処理設計_類似度.md の 7-3「ポップアップ・通知の取り方」・7-5、API設計.md の 16-3 ㉝。
# 似た学生（similar_students.rb）と同じ形。
#
# 選び方（7-3）
#   1. 候補：掲載中の募集から、この学生とやりとりがある募集と、その募集自身を除いたもの
#   2. 候補すべてについて、その募集との近さ f(募集, 募集) を計算する（Recommendation::Similarity。SQL だけで計算する）
#   3. 学生の稼働条件に合う募集を先に、その中は f の高い順。同じ f なら新着順 → 番号の大きい順（PR317）
#   4. 上から5件。合う募集が5件に満たなければ、同じ並びのまま合わない募集が続く
# 全件の近さを Rails に読み込まず、並べ替えと件数の絞り込みまでデータベースで行う（PR316）。
# 番号だけを返す。行の中身（形B）は、窓口が関連をまとめて読み込んで作る
class SimilarJobPostings
  # job_posting：応募した募集。student：応募した学生。
  # 返すもの：似た募集の番号の配列（並べた順。最大 SIMILAR_LIMIT 件）
  def self.ids(job_posting, student)
    # その募集自身は、応募の直後ならやりとりがあるので外れるが、窓口はいつでも呼べるので、はっきり除く
    candidates = JobPosting.published
                           .where.not(id: student.candidacies.select(:job_posting_id))
                           .where.not(id: job_posting.id)
    # 稼働条件に合う候補。募集一覧の「自分の稼働条件で選ぶ」と同じ条件を当てる（PR313）
    matched = JobPostingSearch.new(
      student: student, params: JobPostingSearch.work_condition_params(student)
    ).matched_within(candidates)
    pairs_sql = Recommendation::Similarity.posting_posting_sql([ job_posting.id ], candidates)

    # pairs は「その募集 × 候補」の近さ（left_id・right_id・f）。候補の番号（right_id）で募集とつなぐ
    JobPosting.joins("JOIN (#{pairs_sql}) pairs ON pairs.right_id = job_postings.id")
              .order(
                Arel.sql("CASE WHEN job_postings.id IN (#{matched.select(:id).to_sql}) THEN 0 ELSE 1 END"),
                Arel.sql("pairs.f DESC"),
                published_at: :desc,
                id: :desc
              )
              .limit(Recommendation::Parameters::SIMILAR_LIMIT)
              .pluck(:id)
  end
end
