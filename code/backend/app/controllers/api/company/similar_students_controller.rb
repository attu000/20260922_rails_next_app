# ㉕ この学生に似た学生（GET /api/company/students/:student_id/similar_students）。
# 学生詳細のスカウト送信後のポップアップで使う。詳しくは design/designs/API設計.md の 16-3 ㉕。
# 学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class SimilarStudentsController < BaseController
      # 返事は app/views/api/company/similar_students/index.json.jbuilder
      def index
        # スカウトに使った募集の番号は必須。なければ params.require が 422 にする（16-1-10）
        job_posting_id = params.require(:job_posting_id)
        # 募集は、自社の募集の中から探す。他社の募集の番号なら 404（16-1-10）
        job_posting = current_company.job_postings.find(job_posting_id)
        # 企業はすべての学生を見られる（学生詳細と同じ）。存在しない番号なら 404
        student = StudentProfile.find(params[:student_id])

        ids = SimilarStudents.ids(student, job_posting)
        # 選んだ順のまま読み、形C の関連もまとめて読み込む（N+1問題を避ける）。
        # in_order_of は、番号の並びの順に並べる（Django の Case(When(id=…, then=0), …) で並べるのにあたる）
        @students = StudentProfile.includes(*StudentsController::ROW_ASSOCIATIONS).in_order_of(:id, ids)
      end
    end
  end
end
