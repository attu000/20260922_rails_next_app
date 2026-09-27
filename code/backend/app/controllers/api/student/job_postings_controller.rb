# ⑱ 募集検索と ⑲ 募集詳細。
# 詳しくは design/designs/API設計.md の 16-3 ⑱⑲。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class JobPostingsController < BaseController
      # 学生向けの募集の行（形B）を出すときに、まとめて読み込む関連（会社とそのアイコン、職種、工程、業界、事業形態）。
      # 企業詳細・募集管理・スカウト管理の募集の行でも使う
      ROW_ASSOCIATIONS = [
        { company_profile: { icon_attachment: :blob } },
        :job_posting_job_categories, :job_posting_work_processes, :industries, :business_types
      ].freeze

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
        # この募集との自分のやりとり。なければ nil（返事の my_status は none になる）
        @candidacy = current_student.candidacies.find_by(job_posting: @job_posting)
        # この募集の企業と、自分とのスレッドがあるか
        @has_message_thread = MessageThread.exists_between?(@job_posting.company_profile, current_student)
        # 自分の働き方の好み。カルチャーグラフに黒丸で重ねる（順10。PR258）
        @student = current_student
      end

      private

      # 学生から見てよい募集（掲載中と、自分とやりとりがある募集）の中からだけ探す。
      # 範囲外の番号は、そのまま 404 になる（16-1-10）。範囲は StudentProfile#visible_job_postings の1か所で決める
      def find_visible_job_posting
        current_student.visible_job_postings.find(params[:id])
      end

      # 検索の条件として受け取ってよい値だけを通す。ページ番号（page）は Pagy が直接読む
      def search_params
        # 1つの値を先に、配列（名前: []）をあとに書く（Ruby の決まり）
        params.permit(:q, :sort,
                      # 稼働条件（PR200）
                      :work_days_per_week, :work_hours_per_day, :duration_months, :available_from, :weekend_ok,
                      prefecture_ids: [], job_major_category_ids: [], job_middle_category_ids: [],
                      # 工程（順9。PR251）
                      technology_ids: [], work_process_ids: [], work_styles: [])
      end
    end
  end
end
