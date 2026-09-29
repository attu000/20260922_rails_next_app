# ㊼ プチ職業体験の問題の正否の判定。
# 詳しくは design/designs/API設計.md の 16-3-9。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class JobTrialHurdlesController < BaseController
      # 選んだ選択肢の正否と解説を返す。判定はモデルの JobTrialHurdle#check に置く。
      # 何も記録しない（正否・やり直しの回数・講座の進み具合。PR355）。
      # 間違えたときも正解の選択肢は返さない（正解するまで選び直す形のため）
      def check
        # ハードルはすべての学生が見てよいので、すべてのハードルの中から探す。存在しない番号は 404（16-1-10）
        hurdle = JobTrialHurdle.find(params[:id])
        # 選択肢が送られていなければ、params.require が 422 にする
        result = hurdle.check(params.require(:choice))

        if result
          render json: result
        else
          # その問題にない選択肢（PR395）
          render_error(:unprocessable_content, I18n.t("api.errors.unprocessable"),
                       errors: { choice: [ I18n.t("api.errors.choice_not_in_question") ] })
        end
      end
    end
  end
end
