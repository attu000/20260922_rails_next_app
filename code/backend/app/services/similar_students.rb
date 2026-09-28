# 「この学生に似た学生」を選ぶ（学生詳細のスカウト送信後のポップアップ。㉕）。
# 詳しくは design/designs/処理設計_類似度.md の 7-3「ポップアップ・通知の取り方」・7-5、API設計.md の 16-3 ㉕。
#
# 選び方（7-3）
#   1. 候補：30日以内に活動した学生から、スカウトに使った募集とやりとりがある学生と、本人を除いたもの
#   2. 候補すべてについて、本人との近さ f(学生, 学生) を計算する（Recommendation::Similarity。SQL だけで計算する）
#   3. 募集の稼働条件に合う学生を先に、その中は f の高い順。同じ f なら最終活動が新しい順 → 番号の大きい順（PR317）
#   4. 上から5人。合う学生が5人に満たなければ、同じ並びのまま合わない学生が続くので、補充も同じ問い合わせで済む
# 全員の近さを Rails に読み込まず、並べ替えと件数の絞り込みまでデータベースで行う（PR316）。
# 番号だけを返す。行の中身（形C）は、窓口が関連をまとめて読み込んで作る（N+1問題を避けるため）
class SimilarStudents
  # student：スカウトした学生。job_posting：スカウトに使った自社の募集。
  # 返すもの：似た学生の番号の配列（並べた順。最大 SIMILAR_LIMIT 人）
  def self.ids(student, job_posting)
    # 本人は、スカウトの直後ならやりとりがあるので外れるが、窓口はいつでも呼べるので、はっきり除く
    candidates = StudentProfile.recently_active
                               .where.not(id: job_posting.candidacies.select(:student_profile_id))
                               .where.not(id: student.id)
    # 稼働条件に合う候補。学生検索の「この募集の稼働条件で選ぶ」と同じ条件を当てる（PR313）
    matched = StudentSearch.new(
      company: job_posting.company_profile, job_posting: job_posting,
      params: StudentSearch.work_condition_params(job_posting)
    ).matched_within(candidates)
    pairs_sql = Recommendation::Similarity.student_student_sql([ student.id ], candidates)

    # pairs は「本人 × 候補」の近さ（left_id・right_id・f）。候補の番号（right_id）で学生とつなぐ。
    # Django でいえば、Subquery で f を annotate してから order_by(...)[:5] するのにあたる
    StudentProfile.joins(:user)
                  .joins("JOIN (#{pairs_sql}) pairs ON pairs.right_id = student_profiles.id")
                  .order(
                    Arel.sql("CASE WHEN student_profiles.id IN (#{matched.select(:id).to_sql}) THEN 0 ELSE 1 END"),
                    Arel.sql("pairs.f DESC"),
                    Arel.sql("users.last_active_on DESC"),
                    id: :desc
                  )
                  .limit(Recommendation::Parameters::SIMILAR_LIMIT)
                  .pluck(:id)
  end
end
