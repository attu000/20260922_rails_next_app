# ㊺ プチ職業体験の講座の一覧、㊻ 講座の中身と自分の自己分析。
# 詳しくは design/designs/API設計.md の 16-3-9。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class JobTrialsController < BaseController
      # ㊺ すべての講座を、講座の表示順で返す。ページ分けしない（講座は数本の想定）。
      # 返事は app/views/api/student/job_trials/index.json.jbuilder
      def index
        # 工程もまとめて読む（N+1問題を避ける。Django の prefetch_related にあたる）
        @job_trials = JobTrial.ordered.includes(:work_processes)
        # 修了済み（自己分析を送った）講座の番号。自分の自己分析を1回の問い合わせでまとめて調べる（PR369）
        @completed_job_trial_ids = current_student.self_analyses.pluck(:job_trial_id).to_set
      end

      # ㊻ 講座の中身（正解と解説は含まない。PR377）と、自分のこの講座の自己分析。
      # 講座はすべての学生が見てよいので、すべての講座の中から探す。存在しない番号は 404（16-1-10）。
      # 返事は app/views/api/student/job_trials/show.json.jbuilder
      def show
        @job_trial = JobTrial.includes(:hurdles, :work_processes).find(params[:id])
        # 自己分析は、自分の分の中からだけ探す。なければ nil
        @self_analysis = current_student.self_analyses.find_by(job_trial: @job_trial)
      end
    end
  end
end
