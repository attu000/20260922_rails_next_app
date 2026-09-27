# ㉑ 候補者一覧（GET /api/company/candidacies）と、やりとりの操作 ㉖〜㉚
# （POST /api/company/candidacies/:id/match・decline・undo_decline・pass・fail）。
# 詳しくは design/designs/API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class CandidaciesController < BaseController
      # 操作の前に、自社のやりとりの中から番号で探す（一覧以外の5つ）
      before_action :set_candidacy, except: :index

      # ㉑ 候補者一覧。自社の募集へのやりとりを、1件1行で、やりとりが始まった日の新しい順に返す。
      # job_posting_id を送ると、その募集のやりとりだけにする（募集別のタブ）。
      # 見送り・合格・不合格は既定で隠し、show_all が true のときだけ出す（順11）。
      # 返事は app/views/api/company/candidacies/index.json.jbuilder
      def index
        # 自社のやりとりの中からだけ取り出す（他社のやりとりは入らない。16-1-10）
        candidacies = current_company.candidacies
        if params[:job_posting_id].present?
          # 募集の番号も、自社の募集の中から探す。他社の募集の番号なら 404（16-1-10）
          candidacies = candidacies.where(job_posting: current_company.job_postings.find(params[:job_posting_id]))
        end
        # "true" や "1" を true として読む（募集検索の weekend_ok と同じ読み方）。
        # 絞り込みはデータベースで行うので、ページの件数も隠したあとの行で数える
        candidacies = candidacies.listed_in_company_candidacies unless ActiveModel::Type::Boolean.new.cast(params[:show_all])

        candidacies = candidacies.order(created_at: :desc, id: :desc)
                                 # 行に出す募集と、学生・学生のアイコンをまとめて読む（N+1問題を避ける）
                                 .includes(:job_posting, student_profile: { icon_attachment: :blob })
        @pagy, @candidacies = paginate(candidacies)
      end

      # 下の5つの操作の処理は、モデルの Candidacy にまとめてある（技術構成.md の 9-2）。
      # できない状態の 409 は、モデルが投げる ConflictError を error_responses.rb が返すので、ここには書かない（PR205）。
      # 返事は、操作したあとの、その募集の状態（形D）。画面は読み直さずにボタンを出し直せる（16-3-6）。
      # 5つとも同じ形なので、app/views/api/company/candidacies/state.json.jbuilder を使う（PR270）

      # ㉖ 企業が応募にマッチする
      def match
        @candidacy.match
        render :state
      end

      # ㉗ 見送る
      def decline
        @candidacy.decline
        render :state
      end

      # ㉘ 見送りを取り消す
      def undo_decline
        @candidacy.undo_decline
        render :state
      end

      # ㉙ 合格として保存する（URL は /pass。PR269）
      def mark_passed
        @candidacy.mark_passed
        render :state
      end

      # ㉚ 不合格として保存する（URL は /fail。PR269）
      def mark_failed
        @candidacy.mark_failed
        render :state
      end

      private

      # 自社のやりとりの中からだけ探す。他社のやりとりの番号なら 404（16-1-10）
      def set_candidacy
        @candidacy = current_company.candidacies.find(params[:id])
      end
    end
  end
end
