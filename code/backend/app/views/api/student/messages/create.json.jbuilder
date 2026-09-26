# ㊶ POST /api/student/companies/:company_id/message_thread/messages の形（design/designs/API設計.md の 16-3-7）。
# 作ったメッセージ1件を、㊵ の messages の1要素と同じ形で返す。画面はこれを会話の末尾に足す

json.partial! "api/shared/message", message: @message, viewer: Current.user
