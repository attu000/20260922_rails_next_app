# ㉛ 応募（POST /api/student/candidacies）。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class CandidaciesController < BaseController
      # ㉛ 応募。応募の処理はモデルの Candidacy.apply に1つにまとめてある（技術構成.md の 9-2）。
      # 返事は app/views/api/student/candidacies/create.json.jbuilder。
      # 今の状態ではできないとき（応募済み、掲載中でない）の 409 は、apply が投げる ConflictError を
      # error_responses.rb が返すので、ここには書かない（PR205）
      def create
        # 募集は、自分が見てよい募集の中から探す。範囲の外の番号は 404（16-1-10）。
        # 番号が送られていなければ、params.require が 422 にする
        job_posting = current_student.visible_job_postings.find(params.require(:job_posting_id))
        @candidacy = Candidacy.apply(current_student, job_posting, candidacy_params[:reasons])

        if @candidacy.persisted?
          render :create, status: :created
        else
          render_unprocessable(@candidacy.errors)
        end
      end

      private

      # 受け取ってよい値だけを通す（strong parameters。Django の Serializer の fields にあたる）
      def candidacy_params
        params.permit(:job_posting_id, reasons: [])
      end
    end
  end
end
