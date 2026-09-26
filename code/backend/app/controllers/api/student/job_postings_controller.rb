# ⑱ 募集検索と ⑲ 募集詳細。
# 詳しくは design/designs/API設計.md の 16-3 ⑱⑲。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class JobPostingsController < BaseController
      # 学生向けの募集の行（形B）を出すときに、まとめて読み込む関連（会社とそのアイコン、職種）。
      # 企業詳細（companies_controller.rb）の募集一覧でも使う
      ROW_ASSOCIATIONS = [ { company_profile: { icon_attachment: :blob } }, :job_posting_job_categories ].freeze

      # ⑱ 募集検索。条件で結果を減らさず、合致の群を先に並べて返す（処理設計_類似度.md の 7-3）。
      # 検索の本体は app/services/job_posting_search.rb。
      # 返事は app/views/api/student/job_postings/index.json.jbuilder
      def index
        search = JobPostingSearch.new(student: current_student, params: search_params)
        @pagy, records = paginate(search.ordered)
        @job_postings = preload_records(records, ROW_ASSOCIATIONS)
        @matched_ids = search.matched_ids_in(@job_postings.map(&:id))
        @matched_count = search.matched_count
      end

      # ⑲ 募集詳細。返事は app/views/api/student/job_postings/show.json.jbuilder
      def show
        @job_posting = find_visible_job_posting
      end

      private

      # 学生から見てよい募集の中からだけ探す。範囲外の番号は、そのまま 404 になる（16-1-10）。
      # 今は掲載中の募集だけ。順5 で「自分とやりとりがある募集」（非公開・終了でも開ける）を足す
      def find_visible_job_posting
        JobPosting.published.find(params[:id])
      end

      # 検索の条件として受け取ってよい値だけを通す。ページ番号（page）は Pagy が直接読む
      def search_params
        # 1つの値を先に、配列（名前: []）をあとに書く（Ruby の決まり）
        params.permit(:q, :sort,
                      # 稼働条件（PR200）
                      :work_days_per_week, :work_hours_per_day, :duration_months, :available_from, :weekend_ok,
                      prefecture_ids: [], job_major_category_ids: [], job_middle_category_ids: [],
                      technology_ids: [], work_styles: [])
      end
    end
  end
end
