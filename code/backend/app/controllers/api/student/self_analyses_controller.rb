# ㊽ プチ職業体験の自己分析の保存。
# 詳しくは design/designs/API設計.md の 16-3-9、サービス概要_コンセプト.md の 12-4。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class SelfAnalysesController < BaseController
      # 自分のこの講座の自己分析があれば上書きし、なければ作る（1人×1講座に1件。PR371）。
      # 初めて作ったときも 200 にする（作る・上書きを1つの窓口で行うため）。講座を最後まで通ったかは確かめない（PR387）。
      # 同時に2回押されたときの 409 は、SelfAnalysis.save_for が投げる ConflictError を
      # error_responses.rb が返すので、ここには書かない。
      # 返事は app/views/api/student/self_analyses/update.json.jbuilder
      def update
        # 講座はすべての学生が見てよいので、すべての講座の中から探す。存在しない番号は 404（16-1-10）
        job_trial = JobTrial.find(params[:job_trial_id])
        @self_analysis = SelfAnalysis.save_for(current_student, job_trial, self_analysis_params)

        if @self_analysis.errors.empty?
          render :update
        else
          render_unprocessable(@self_analysis.errors)
        end
      end

      private

      # 受け取ってよい値だけを通す（strong parameters。Django の Serializer の fields にあたる）
      def self_analysis_params
        params.permit(*SelfAnalysis::PERMITTED_ATTRIBUTES)
      end
    end
  end
end
