# 「おすすめの学生」の通知を作る（C10。応募・マッチのあとのジョブ InterestRecordedJob が呼ぶ）。
# 詳しくは design/designs/処理設計_類似度.md の 7-3「ポップアップ・通知の取り方」・7-5「応募・マッチ時の手順」、ページ設計.md の 6-5 C10。
# 似た募集のポップアップ（similar_job_postings.rb）と同じ近さ・同じ稼働条件の判定を使い、1社1件にまとめる。
#
# 選び方
#   1. 候補：掲載中の募集から、学生とやりとりがある募集、応募・マッチした会社自身の募集（PR321）、
#      この学生の通知をもう受け取った会社の募集（PR322）を除いたもの
#   2. 候補すべてについて、応募・マッチした募集との近さ f(募集, 募集) を計算する（Recommendation::Similarity。SQL だけで計算する）
#   3. 会社ごとに代表の募集を1件選ぶ。学生の稼働条件に合う募集が先 → f の高い順 → 新着順 → 番号の大きい順の先頭（PR324）
#   4. 代表を同じ順で並べ、上から5社
# 会社の選び方はすべてデータベースで行い、Rails が受け取るのは多くても5件の募集だけにする
class RecommendedStudentNotifications
  # student：応募・マッチした学生。job_posting：応募・マッチした募集。
  # 返すもの：作った通知の配列（最大 SIMILAR_LIMIT 件）
  def self.create_for(student, job_posting)
    # 30日以上活動のない学生には通知を作らない（7-3 の「それでも除外するもの」）。応募・マッチの直後なので、ふつうは活動中
    return [] unless StudentProfile.recently_active.exists?(student.id)

    postings = notified_postings(student, job_posting)
    # 全社分を1つのトランザクションで作る。途中で失敗したら1件も残さない
    Notification.transaction do
      postings.map do |posting|
        Notification.create!(
          user_id: posting.company_profile.user_id,
          student_profile: student,
          kind: :recommended_student,
          # 本文に、応募・マッチした募集のことや、他社での行動を書かない（ページ設計.md の 6-5 C10）
          body: "#{posting.title}に合いそうな学生がいます",
          # 通知先の募集のタブを選んだ状態の学生詳細（API設計.md の 16-1-13）
          link_path: "/company/students/#{student.id}?job_posting_id=#{posting.id}"
        )
      end
    end
  end

  # 通知先の募集（1社1件。並べた順。最大 SIMILAR_LIMIT 件）
  def self.notified_postings(student, job_posting)
    # この学生の「おすすめの学生」の通知を、もう受け取った会社（PR322・PR323）
    notified_company_ids = CompanyProfile.where(
      user_id: Notification.recommended_student.where(student_profile: student).select(:user_id)
    ).select(:id)
    # 応募・マッチした募集は、やりとりがあるので1つ目の除外で外れる
    candidates = JobPosting.published
                           .where.not(id: student.candidacies.select(:job_posting_id))
                           .where.not(company_profile_id: job_posting.company_profile_id)
                           .where.not(company_profile_id: notified_company_ids)
    # 稼働条件に合う候補。似た募集のポップアップと同じく、募集一覧の「自分の稼働条件で選ぶ」と同じ条件を当てる（PR313・PR324）
    matched = JobPostingSearch.new(
      student: student, params: JobPostingSearch.work_condition_params(student)
    ).matched_within(candidates)
    pairs_sql = Recommendation::Similarity.posting_posting_sql([ job_posting.id ], candidates)

    # 会社ごとの代表。DISTINCT ON は「会社ごとに、並べた先頭の1行だけ残す」PostgreSQL の機能で、
    # 並べる順の最初を会社の番号にする決まりがある。
    # Django の order_by("company_profile_id", "matched_rank", "-f", ...).distinct("company_profile_id") にあたる
    representatives = JobPosting
      .joins("JOIN (#{pairs_sql}) pairs ON pairs.right_id = job_postings.id")
      .select(
        "DISTINCT ON (job_postings.company_profile_id) job_postings.*",
        "CASE WHEN job_postings.id IN (#{matched.select(:id).to_sql}) THEN 0 ELSE 1 END AS matched_rank",
        "pairs.f AS f"
      )
      .order(
        Arel.sql("job_postings.company_profile_id"),
        Arel.sql("matched_rank"),
        Arel.sql("pairs.f DESC"),
        published_at: :desc,
        id: :desc
      )

    # 代表を、合う → f → 新着 → 番号の順に並べ直して、上から5社。
    # from は代表の問い合わせを、job_postings という名前の表として外側から読む（Django の Subquery を FROM に置くのにあたる）
    JobPosting.from(representatives, :job_postings)
              .order(
                Arel.sql("job_postings.matched_rank"),
                Arel.sql("job_postings.f DESC"),
                published_at: :desc,
                id: :desc
              )
              .limit(Recommendation::Parameters::SIMILAR_LIMIT)
              .includes(:company_profile)
              .to_a
  end
  private_class_method :notified_postings
end
