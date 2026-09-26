# ㉓ 学生詳細（GET /api/company/students/:id）。
# 詳しくは design/designs/API設計.md の 16-3-6。学生なら 403 は親（BaseController）が返す。
# ㉒ 学生検索（index）は順6 で足す
module Api
  module Company
    class StudentsController < BaseController
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
      end
    end
  end
end
