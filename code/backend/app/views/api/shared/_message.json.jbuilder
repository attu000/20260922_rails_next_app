# メッセージ1件の部品（design/designs/API設計.md の 16-3 ㊲㊵ の messages の1要素。㊳㊶ の返事も同じ形）。
# 企業・学生のチャットと送信で使い回す。
# 使い方：json.partial! "api/shared/message", message: メッセージ, viewer: 今ログインしている人（Current.user）
#
# メッセージ1件ずつにアイコンは持たせない。1対1の会話なので、自分のアイコンは ③、相手のアイコンは partner.icon_url から取れる

json.id message.id
# 自分が送ったメッセージなら true（画面で左右に分けて出すため）
json.is_mine message.sender_user_id == viewer.id
json.body message.body
json.created_at message.created_at
# スカウト文のときだけ、どの募集のスカウトかを入れる。ふつうのメッセージなら null
if message.scout_message
  json.scout do
    job_posting = message.scout_message.candidacy.job_posting
    json.job_posting do
      json.id job_posting.id
      json.title job_posting.title
    end
  end
else
  json.scout nil
end
