# ㉑ 候補者一覧（GET /api/company/candidacies）。
# 詳しくは design/designs/API設計.md の 16-3-6。学生なら 403 は親（BaseController）が返す
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
    end
  end
end
