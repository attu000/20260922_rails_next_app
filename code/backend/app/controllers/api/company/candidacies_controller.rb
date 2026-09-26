# ㉑ 候補者一覧（GET /api/company/candidacies）と ㉖ マッチ（POST /api/company/candidacies/:id/match）。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class CandidaciesController < BaseController
      # ㉑ 候補者一覧。自社の募集へのやりとりを、1件1行で、やりとりが始まった日の新しい順に返す。
      # job_posting_id を送ると、その募集のやりとりだけにする（募集別のタブ）。
      # 見送り・合格・不合格を既定で隠す切り替え（show_all）は、順11 で足す。
      # 返事は app/views/api/company/candidacies/index.json.jbuilder
      def index
        # 自社のやりとりの中からだけ取り出す（他社のやりとりは入らない。16-1-10）
        candidacies = current_company.candidacies
        if params[:job_posting_id].present?
          # 募集の番号も、自社の募集の中から探す。他社の募集の番号なら 404（16-1-10）
          candidacies = candidacies.where(job_posting: current_company.job_postings.find(params[:job_posting_id]))
        end

        candidacies = candidacies.order(created_at: :desc, id: :desc)
                                 # 行に出す募集と、学生・学生のアイコンをまとめて読む（N+1問題を避ける）
                                 .includes(:job_posting, student_profile: { icon_attachment: :blob })
        @pagy, @candidacies = paginate(candidacies)
      end

      # ㉖ 企業が応募にマッチする。処理はモデルの Candidacy#match に1つにまとめてある（技術構成.md の 9-2）。
      # できない状態（スカウト由来、マッチ済み、募集が掲載中でない）の 409 は、match が投げる ConflictError を
      # error_responses.rb が返すので、ここには書かない（PR205）。
      # 返事は、その募集の状態（形D）。画面は読み直さずにボタンを出し直せる（16-3-6）。
      # app/views/api/company/candidacies/match.json.jbuilder
      def match
        # 自社のやりとりの中からだけ探す。他社のやりとりの番号なら 404（16-1-10）
        @candidacy = current_company.candidacies.find(params[:id])
        @candidacy.match
      end
    end
  end
end
