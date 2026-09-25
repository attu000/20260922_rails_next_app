# ⑪ 自社の募集の一覧、⑫ 1件、⑬ 新規作成、⑭ 保存・状態の変更。
# 詳しくは design/designs/API設計.md の 16-3 ⑪〜⑭。学生なら 403 は親（BaseController）が返す。
# Django REST framework の ViewSet にあたる
module Api
  module Company
    class JobPostingsController < BaseController
      # ⑪ 一覧。自社の全募集（非公開・終了も含む）を、最終更新の新しい順に。ページ分けしない（16-1-11）。
      # 返事は app/views/api/company/job_postings/index.json.jbuilder
      def index
        @job_postings = current_company.job_postings.order(updated_at: :desc, id: :desc)
      end

      # ⑫ 1件。返事は app/views/api/company/job_postings/show.json.jbuilder
      def show
        @job_posting = find_own_job_posting
      end

      # ⑬ 新規作成。会社はここで決まる（送られた値では決めない）。
      # 保存の処理はモデルの save_posting に1つにまとめてある（技術構成.md の 9-1-1 の4、9-2）
      def create
        @job_posting = current_company.job_postings.new

        if @job_posting.save_posting(job_posting_params)
          # ⑫と同じ形で返す（16-3 ⑬）
          render :show, status: :created
        else
          render_unprocessable(@job_posting.errors)
        end
      end

      # ⑭ 保存。状態の変更も、ほかの項目と一緒にここで行う（16-1-4 の例外）
      def update
        @job_posting = find_own_job_posting

        if @job_posting.save_posting(job_posting_params)
          render :show, status: :ok
        else
          render_unprocessable(@job_posting.errors)
        end
      end

      private

      # 自社の募集の中からだけ探す。他社の番号は見つからず、そのまま 404 になる（16-1-10）。
      # Django の get_object_or_404(JobPosting, pk=id, company_profile=自社) にあたる
      def find_own_job_posting
        current_company.job_postings.find(params[:id])
      end

      # 受け取ってよい値だけを通す（strong parameters。Django の Serializer の fields にあたる）。
      # id、published_at、company_profile_id、updated_at などを送られても、ここで捨てる
      def job_posting_params
        params.permit(
          :status, :title, :about, :business_description, :internship_details, :growth,
          :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months, :start_month,
          :work_style, :work_style_note, :prefecture_id, :work_location_note, :weekend_ok, :work_note,
          :hourly_wage, :requirements, :preferred_requirements, :technology_note,
          main_job_middle_category_ids: [], related_job_middle_category_ids: [], technology_ids: []
        )
      end
    end
  end
end
