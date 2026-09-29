# ㊾ 企業向けのプチ職業体験の講座の中身。
# 詳しくは design/designs/API設計.md の 16-3-9。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class JobTrialsController < BaseController
      # 講座の中身（正解と解説を含む。PR373）。学生の自己分析が何の話をしているかを知るために読む。
      # 講座はすべての企業が見てよいので、すべての講座の中から探す。存在しない番号は 404（16-1-10）。
      # 返事は app/views/api/company/job_trials/show.json.jbuilder
      def show
        @job_trial = JobTrial.includes(:hurdles, :work_processes).find(params[:id])
      end
    end
  end
end
