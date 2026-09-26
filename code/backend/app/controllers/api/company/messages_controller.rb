# ㊳ 送信（POST /api/company/students/:student_id/message_thread/messages）。
# 詳しくは design/designs/API設計.md の 16-3-7、権限_バリデーション.md の 17-2-3。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class MessagesController < BaseController
      # 送る処理はモデルの MessageThread#post_message に1つにまとめてある。
      # 返事は、作ったメッセージ1件（㊲の messages の1要素と同じ形）。app/views/api/company/messages/create.json.jbuilder。
      # 送れないとき（マッチ以降のやりとりがない）の 409 は、post_message が投げる ConflictError を
      # error_responses.rb が返すので、ここには書かない
      def create
        # スレッドの探し方は ㊲ と同じ。なければ 404
        thread = current_company.message_threads.find_by!(student_profile_id: params[:student_id])
        # 本文は params.require にしない。送られていなくても「本文を入力してください」と出すため（スカウト文と同じ）
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
