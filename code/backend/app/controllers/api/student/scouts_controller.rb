# ㉟ スカウト管理（GET /api/student/scouts）。
# 詳しくは design/designs/API設計.md の 16-3-6、データベース.md の 8-7。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class ScoutsController < BaseController
      # 届いたスカウトのうち、まだマッチしていないもの（見送りも含む）を、スカウトが届いた日の新しい順に返す。
      # 自分のやりとりの中からだけ取り出すので、他人のやりとりは入らない（16-1-10）。
      # 返事は app/views/api/student/scouts/index.json.jbuilder
      def index
        candidacies = current_student.candidacies.listed_in_student_scouts
                                     .order(created_at: :desc, id: :desc)
                                     # 行（形B）に出す募集・会社・アイコン・職種をまとめて読む（N+1問題を避ける）
                                     .includes(job_posting: JobPostingsController::ROW_ASSOCIATIONS)
        @pagy, @candidacies = paginate(candidacies)
      end
    end
  end
end
