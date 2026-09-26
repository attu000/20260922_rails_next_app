# ㊱ スレッド一覧（GET /api/company/message_threads）と ㊲ チャット（GET /api/company/students/:student_id/message_thread）。
# 詳しくは design/designs/API設計.md の 16-3-7、権限_バリデーション.md の 17-2-3。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class MessageThreadsController < BaseController
      # ㊱ 自社のスレッドを、最後のメッセージの新しい順に（メッセージがなければ作った日時で比べる。PR221）。
      # 返事は app/views/api/company/message_threads/index.json.jbuilder
      def index
        threads = current_company.message_threads
                                 .recent_first
                                 # 相手の学生とアイコンをまとめて読む（N+1問題を避ける）
                                 .includes(student_profile: { icon_attachment: :blob })
        @pagy, @threads = paginate(threads)
      end

      # ㊲ その学生とのチャット。メッセージは古い順に全件（ページ分けしない。16-1-11）。
      # 送れるか（can_send）は MessageThread#can_send? が決める。
      # 返事は app/views/api/company/message_threads/show.json.jbuilder
      def show
        # スレッドは、自社のスレッドの中から探す。学生が存在しない、まだスレッドがない、
        # 他社とその学生のスレッドしかない、のどれも 404（16-1-10）
        @thread = current_company.message_threads.find_by!(student_profile_id: params[:student_id])
        @messages = @thread.messages
                           .order(:created_at, :id)
                           # スカウト文なら、どの募集のスカウトかをまとめて読む（技術構成.md の 9-2）
                           .includes(scout_message: { candidacy: :job_posting })
      end
    end
  end
end
