# ㉔ スカウト（POST /api/company/scouts）。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class ScoutsController < BaseController
      # スカウトの処理はモデルの Candidacy.send_scout に1つにまとめてある（技術構成.md の 9-2）。
      # 返事は、スカウトしたあとの、その募集の状態（形D）。app/views/api/company/scouts/create.json.jbuilder。
      # 今の状態ではできないとき（やりとりがもうある、掲載中でない）の 409 は、send_scout が投げる ConflictError を
      # error_responses.rb が返すので、ここには書かない（PR205）
      def create
        # 募集は、自社の募集の中から探す。他社の募集の番号なら 404（16-1-10）。
        # 番号が送られていなければ、params.require が 422 にする
        job_posting = current_company.job_postings.find(params.require(:job_posting_id))
        # 学生は、すべての学生の中から探す（どの学生にもスカウトできる。16-3-6）。存在しない番号は 404
        student = StudentProfile.find(params.require(:student_profile_id))
        # スカウト文は params.require にしない。送られていなくても「スカウト文を入力してください」と出すため
        @candidacy = Candidacy.send_scout(job_posting, student, params[:body])

        if @candidacy.persisted?
          render :create, status: :created
        else
          render_unprocessable(@candidacy.errors)
        end
      end
    end
  end
end
