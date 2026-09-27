# ⑮ GET /api/student/profile（自分のプロフィール）と ⑯ PATCH /api/student/profile（保存）。
# 詳しくは design/designs/API設計.md の 16-3 ⑮⑯。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class ProfilesController < BaseController
      # 受け取ってよい項目の一覧（strong parameters に渡すもの）。
      # ⑥ 学生の新規登録（student_registrations_controller.rb）も、アカウントの3つに加えて、この一覧を使う。
      # 1か所に書くことで、項目を足したときに登録の側だけ足し忘れることを防ぐ。
      # 外部リンク・資格・興味のある業界・就活希望エリアは【仕上げ】で足す
      PERMITTED_PARAMS = [
        :name, :university_id, :university_other_name, :faculty_id, :department_id,
        :grade, :prefecture_id, :self_pr_strength, :self_pr_weakness, :self_pr_future,
        :graduation_year, :activity_status,
        :work_days_per_week, :work_hours_per_day, :duration_months, :available_from,
        :can_full_remote, :can_partial_remote, :can_onsite, :work_note,
        # 働き方の好み（性格）の5軸（PR233）
        :personality_pace, :personality_novelty, :personality_collaboration,
        :personality_decision, :personality_atmosphere,
        { interested_job_middle_category_ids: [], commutable_prefecture_ids: [],
          skills: %i[technology_id other_name years level] }
      ].freeze

      # ⑮ 表示。返事は app/views/api/student/profiles/show.json.jbuilder
      def show
        @student = current_student
      end

      # ⑯ 保存。保存の処理はモデルの save_profile に1つにまとめてある（技術構成.md の 9-2）
      def update
        @student = current_student

        if @student.save_profile(profile_params)
          # ⑮と同じ形で返す（16-3 ⑯）
          render :show, status: :ok
        else
          render_unprocessable(@student.errors)
        end
      end

      private

      # 受け取ってよい値だけを通す（strong parameters。Django の Serializer の fields にあたる）。
      # icon_url や user_id などを送られても、ここで捨てる
      def profile_params
        params.permit(*PERMITTED_PARAMS)
      end
    end
  end
end
