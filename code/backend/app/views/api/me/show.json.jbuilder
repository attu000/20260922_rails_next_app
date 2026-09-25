# 形A：ログイン中の人（design/designs/API設計.md の 16-3-2）。
# ① ログイン、③ ログイン中の人（今後は ⑤⑥ 新規登録も）の返事は、すべてこのテンプレートを使う。形はここだけに書く

json.id @user.id
# 番号ではなく名前（"company" か "student"）で返す（16-1-8）
json.role @user.role
# 企業なら会社名、学生なら氏名
json.name @profile&.name
# アイコンの URL。なければ null。学生は、学生のアイコンを作る順3 までは null（未決内容.md の 11-2）
json.partial! "api/shared/icon_url", record: @profile
# 企業なら未読の通知の件数、学生なら null。通知の機能を作る Phase 6 で埋める（未決内容.md の 11-2）。
# まだ数えられないので、0（未読が0件）ではなく null にしている
json.unread_notifications_count nil
