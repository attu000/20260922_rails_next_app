# ⑳ 企業詳細。
# 詳しくは design/designs/API設計.md の 16-3 ⑳。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class CompaniesController < BaseController
      # ⑳ 企業のプロフィールと、その企業の掲載中の募集。
      # 学生はすべての企業を見られる（16-1-10）。存在しない番号は 404。
      # 返事は app/views/api/student/companies/show.json.jbuilder
      def show
        @company = CompanyProfile.find(params[:id])
        # 掲載中の募集を、最初に掲載した日時の新しい順に。ページ分けしない（16-1-11）
        @job_postings = @company.job_postings.published
                                .order(published_at: :desc, id: :desc)
                                .includes(JobPostingsController::ROW_ASSOCIATIONS)
      end
    end
  end
end
