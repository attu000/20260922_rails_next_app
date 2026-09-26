# ㊴ スレッド一覧（GET /api/student/message_threads）と ㊵ チャット（GET /api/student/companies/:company_id/message_thread）。
# 詳しくは design/designs/API設計.md の 16-3-7、権限_バリデーション.md の 17-2-3。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class MessageThreadsController < BaseController
      # ㊴ 自分のスレッドを、最後のメッセージの新しい順に（メッセージがなければ作った日時で比べる。PR221）。
      # 返事は app/views/api/student/message_threads/index.json.jbuilder
      def index
        threads = current_student.message_threads
                                 .recent_first
                                 # 相手の企業とアイコンをまとめて読む（N+1問題を避ける）
                                 .includes(company_profile: { icon_attachment: :blob })
        @pagy, @threads = paginate(threads)
      end

      # ㊵ その企業とのチャット。メッセージは古い順に全件（ページ分けしない。16-1-11）。
      # スカウトが届いただけ（まだマッチしていない）でも開ける。スカウト文をマッチ前に読めるようにするため（17-2-3）。
      # 返事は app/views/api/student/message_threads/show.json.jbuilder
      def show
        # スレッドは、自分のスレッドの中から探す。企業が存在しない、まだスレッドがない、
        # ほかの学生とその企業のスレッドしかない、のどれも 404（16-1-10）
        @thread = current_student.message_threads.find_by!(company_profile_id: params[:company_id])
        @messages = @thread.messages
                           .order(:created_at, :id)
                           # スカウト文なら、どの募集のスカウトかをまとめて読む（技術構成.md の 9-2）
                           .includes(scout_message: { candidacy: :job_posting })
      end
    end
  end
end
