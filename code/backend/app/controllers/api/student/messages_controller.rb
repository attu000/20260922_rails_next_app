# ㊶ 送信（POST /api/student/companies/:company_id/message_thread/messages）。
# 詳しくは design/designs/API設計.md の 16-3-7、権限_バリデーション.md の 17-2-3。企業なら 403 は親（BaseController）が返す
module Api
  module Student
    class MessagesController < BaseController
      # 送る処理はモデルの MessageThread#post_message に1つにまとめてある（企業側の ㊳ と同じ）。
      # 返事は、作ったメッセージ1件（㊵の messages の1要素と同じ形）。app/views/api/student/messages/create.json.jbuilder。
      # 送れないとき（マッチ以降のやりとりがない）の 409 は、post_message が投げる ConflictError を
      # error_responses.rb が返すので、ここには書かない
      def create
        # スレッドの探し方は ㊵ と同じ。なければ 404
        thread = current_student.message_threads.find_by!(company_profile_id: params[:company_id])
        # 本文は params.require にしない。送られていなくても「本文を入力してください」と出すため
        @message = thread.post_message(current_user, params[:body])

        if @message.persisted?
          render :create, status: :created
        else
          render_unprocessable(@message.errors)
        end
      end
    end
  end
end
