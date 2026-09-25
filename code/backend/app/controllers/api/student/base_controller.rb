# 学生の窓口（/api/student/…）の共通の親。学生の窓口は、すべてこれを親にする。
# 種別の確認を、ここ1か所にだけ書く（design/designs/API設計.md の 16-1-3・16-1-6）。
# Django で、IsAuthenticated の後に「学生だけ」の権限クラスを並べるのにあたる。
#
# 前処理は親から順に動く：CSRF の合言葉の Cookie → 合言葉の確認（403）→ ログインの確認（401）→ 種別の確認（403。ここ）。
# ログインの確認が先なので、未ログインの人には 403 ではなく 401 が返る（16-1-10）
module Api
  module Student
    class BaseController < ApplicationController
      before_action :require_student

      private

      def require_student
        render_forbidden unless current_user.student?
      end
    end
  end
end
