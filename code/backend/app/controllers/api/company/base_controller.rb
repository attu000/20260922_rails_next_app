# 企業の窓口（/api/company/…）の共通の親。企業の窓口は、すべてこれを親にする。
# 種別の確認を、ここ1か所にだけ書く（design/designs/API設計.md の 16-1-3・16-1-6）。
# Django で、IsAuthenticated の後に「企業だけ」の権限クラスを並べるのにあたる。
#
# 前処理は親から順に動く：CSRF の合言葉の Cookie → 合言葉の確認（403）→ ログインの確認（401）→ 種別の確認（403。ここ）。
# ログインの確認が先なので、未ログインの人には 403 ではなく 401 が返る（16-1-10）
module Api
  module Company
    class BaseController < ApplicationController
      before_action :require_company

      private

      def require_company
        render_forbidden unless current_user.company?
      end
    end
  end
end
