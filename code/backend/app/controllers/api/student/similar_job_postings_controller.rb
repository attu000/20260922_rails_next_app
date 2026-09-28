# ㉝ この募集に似た募集（GET /api/student/job_postings/:job_posting_id/similar_job_postings）。
# 募集詳細の応募完了のポップアップで使う。詳しくは design/designs/API設計.md の 16-3 ㉝。
# 企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class SimilarJobPostingsController < BaseController
      # 返事は app/views/api/student/similar_job_postings/index.json.jbuilder
      def index
        # 学生から見てよい募集（掲載中と、自分とやりとりがある募集）の中からだけ探す。範囲外は 404（募集詳細と同じ。16-1-10）。
        # 応募の直後なら、やりとりがあるので、その間に募集が終了しても開ける
        job_posting = current_student.visible_job_postings.find(params[:job_posting_id])

        ids = SimilarJobPostings.ids(job_posting, current_student)
        # 選んだ順のまま読み、形B の関連もまとめて読み込む（N+1問題を避ける）
        @job_postings = JobPosting.includes(*JobPostingsController::ROW_ASSOCIATIONS).in_order_of(:id, ids)
      end
    end
  end
end
