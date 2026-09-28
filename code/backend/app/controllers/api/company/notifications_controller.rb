# ㊷ 通知の一覧（GET /api/company/notifications）、㊸ 1件を既読にする（POST /api/company/notifications/:id/read）、
# ㊹ すべて既読にする（POST /api/company/notifications/read_all）。順15。
# 詳しくは design/designs/API設計.md の 16-3-8、権限_バリデーション.md の 17-1。学生なら 403 は親（BaseController）が返す。
#
# 通知は会社ではなくアカウント（user_id）宛てなので、ログイン中の人の通知から探す。
# 1社のアカウントは1つなので、「自社宛て」と同じ意味になる
module Api
  module Company
    class NotificationsController < BaseController
      # ㊷ 自社宛ての通知を新しい順に。返事は app/views/api/company/notifications/index.json.jbuilder
      def index
        @pagy, @notifications = paginate(current_user.notifications.latest_first)
      end

      # ㊸ 1件を既読にする。すでに既読でも 204（何度押しても同じ結果）
      def read
        # 自分宛ての通知の中から探す。他社宛てや、ない番号は 404（16-1-10）。
        # Django の get_object_or_404(request.user.notifications, pk=id) にあたる
        current_user.notifications.find(params[:id]).mark_read!
        head :no_content
      end

      # ㊹ 自分宛ての未読をすべて既読にする。未読がなくても 204
      def read_all
        current_user.notifications.mark_all_read!
        head :no_content
      end
    end
  end
end
