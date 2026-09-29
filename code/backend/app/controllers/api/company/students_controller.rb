# ㉒ 学生検索（GET /api/company/students）と ㉓ 学生詳細（GET /api/company/students/:id）。
# 詳しくは design/designs/API設計.md の 16-3-6。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class StudentsController < BaseController
      # 企業向けの学生の行（形C）を出すときに、まとめて読み込む関連
      # （アイコン、プログラミング歴、興味のある職種、最終活動の目安に使うログイン情報）
      ROW_ASSOCIATIONS = [ { icon_attachment: :blob }, :student_skills, :student_interested_job_categories, :user ].freeze
      # 学生詳細の比較（順10）で使う関連。学生の側と募集の側（app/services/student_job_posting_comparison.rb）
      COMPARISON_STUDENT_ASSOCIATIONS = %i[
        student_interested_industries student_interested_job_categories student_skills student_commutable_prefectures
      ].freeze
      COMPARISON_JOB_POSTING_ASSOCIATIONS = %i[job_posting_industries job_posting_job_categories job_posting_technologies].freeze

      # ㉒ 学生検索。条件で結果を減らさず、合致の群を先に並べて返す（処理設計_類似度.md の 7-3）。
      # 検索の本体は app/services/student_search.rb。
      # 返事は app/views/api/company/students/index.json.jbuilder
      def index
        # おすすめ順は、選んだ募集を元に並べるので、募集の番号が必須。なければ params.require が 422 にする（16-1-10）
        params.require(:job_posting_id) if params[:sort] == "recommended"
        # 募集は、自社の募集の中から探す。他社の募集の番号なら 404（16-1-10）
        job_posting = current_company.job_postings.find(params[:job_posting_id]) if params[:job_posting_id].present?

        search = StudentSearch.new(company: current_company, job_posting: job_posting, params: search_params)
        @pagy, records = paginate(search.ordered)
        @students = preload_records(records, ROW_ASSOCIATIONS)
        student_ids = @students.map(&:id)
        @matched_ids = search.matched_ids_in(student_ids)
        @matched_count = search.matched_count

        # 行のタグ用（PR219）。1ページ分の学生について、まとめて1回ずつ取り出す（1行ごとに問い合わせない。N+1問題を避ける）
        # 募集を選んだときの、その募集とのやりとり（学生の番号で引ける）。除外のあとなので、残っているのは未対応応募だけ（PR220）
        @candidacies_by_student_id =
          job_posting ? job_posting.candidacies.where(student_profile_id: student_ids).index_by(&:student_profile_id) : {}
        # 自社の募集とのやりとりの件数（学生の番号 => 件数）。募集を選ばないときの「やりとりあり」に使う。他社の分は数えない
        @candidacy_counts = current_company.candidacies.where(student_profile_id: student_ids).group(:student_profile_id).count
      end

      # ㉓ 学生のプロフィールと、自社の全募集ぶんの状態・押せるボタン・比較。
      # 返事は app/views/api/company/students/show.json.jbuilder
      def show
        # 企業はすべての学生を見られる（16-1-10）。30日以上活動のない学生も、候補者一覧などから開けるよう、ここでは外さない。
        # 存在しない番号は 404。
        # 比較に使う関連は、最初にまとめて読み込む（includes。Django の prefetch_related にあたる）。
        # 募集が何件あっても、学生の関連を募集ごとに読み直さない（N+1問題を避ける）
        # 最終活動の目安に使うログイン情報（user）も一緒に読む
        @student = StudentProfile.includes(*COMPARISON_STUDENT_ASSOCIATIONS, :user).find(params[:id])
        # 自社の全募集（非公開・終了も含む）を、⑪ 募集一覧と同じ順（最終更新の新しい順）に。比較に使う関連も一緒に読む
        @job_postings = current_company.job_postings.includes(*COMPARISON_JOB_POSTING_ASSOCIATIONS)
                                       .order(updated_at: :desc, id: :desc)
        # この学生と自社のやりとりを一度にまとめて取り出し、募集の番号で引けるようにする（募集ごとに探しに行かない。N+1問題を避ける）
        # 押せるボタンの判定で、やりとりから募集の状態を見るので、募集も一緒に読む。応募理由（reasons）も一緒に読む
        @candidacies_by_job_posting_id = current_company.candidacies.where(student_profile: @student)
                                                        .includes(:job_posting, :candidacy_reasons)
                                                        .index_by(&:job_posting_id)
        # 自社と、この学生とのスレッドがあるか（募集ごとではなく、学生ごとの値）
        @has_message_thread = MessageThread.exists_between?(current_company, @student)
      end

      private

      # 検索の条件として受け取ってよい値だけを通す。ページ番号（page）は Pagy が直接読む。
      # job_posting_id は、上で自社の募集の中から探してから渡すので、ここには入れない
      def search_params
        # 1つの値を先に、配列（名前: []）をあとに書く（Ruby の決まり）
        params.permit(:q, :sort,
                      # 稼働条件
                      :work_days_per_week, :work_hours_per_day, :duration_months, :start_month, :work_style, :prefecture_id,
                      :min_level,
                      technology_ids: [], job_major_category_ids: [], job_middle_category_ids: [],
                      grades: [], graduation_years: [], activity_statuses: [])
      end
    end
  end
end
