# ㉒ 学生検索（GET /api/company/students）と ㉓ 学生詳細（GET /api/company/students/:id）。
# 詳しくは design/designs/API設計.md の 16-3-6。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class StudentsController < BaseController
      # 企業向けの学生の行（形C）を出すときに、まとめて読み込む関連（アイコン、プログラミング歴、興味のある職種）
      ROW_ASSOCIATIONS = [ { icon_attachment: :blob }, :student_skills, :student_interested_job_categories ].freeze

      # ㉒ 学生検索。条件で結果を減らさず、合致の群を先に並べて返す（処理設計_類似度.md の 7-3）。
      # 検索の本体は app/services/student_search.rb。
      # 返事は app/views/api/company/students/index.json.jbuilder
      def index
        # おすすめ順は、選んだ募集を元に並べるので、募集の番号が必須。なければ params.require が 422 にする（16-1-10）
        params.require(:job_posting_id) if params[:sort] == "recommended"
        # 募集は、自社の募集の中から探す。他社の募集の番号なら 404（16-1-10）
        job_posting = current_company.job_postings.find(params[:job_posting_id]) if params[:job_posting_id].present?

        search = StudentSearch.new(job_posting: job_posting, params: search_params)
        @pagy, records = paginate(search.ordered)
        @students = preload_records(records, ROW_ASSOCIATIONS)
        @matched_ids = search.matched_ids_in(@students.map(&:id))
        @matched_count = search.matched_count
      end

      # ㉓ 学生のプロフィールと、自社の全募集ぶんの状態・押せるボタン。
      # 返事は app/views/api/company/students/show.json.jbuilder
      def show
        # 企業はすべての学生を見られる（16-1-10）。30日以上活動のない学生も、候補者一覧などから開けるよう、ここでは外さない。
        # 存在しない番号は 404
        @student = StudentProfile.find(params[:id])
        # 自社の全募集（非公開・終了も含む）を、⑪ 募集一覧と同じ順（最終更新の新しい順）に
        @job_postings = current_company.job_postings.order(updated_at: :desc, id: :desc)
        # この学生と自社のやりとりを一度にまとめて取り出し、募集の番号で引けるようにする（募集ごとに探しに行かない。N+1問題を避ける）
        # 押せるボタンの判定で、やりとりから募集の状態を見るので、募集も一緒に読む
        @candidacies_by_job_posting_id = current_company.candidacies.where(student_profile: @student)
                                                        .includes(:job_posting).index_by(&:job_posting_id)
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
