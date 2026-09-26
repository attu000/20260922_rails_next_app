# メッセージの相手の "partner" の部品（design/designs/API設計.md の 16-3 ㊱〜㊵）。
# 企業から見れば学生、学生から見れば企業。企業プロフィールも学生プロフィールも name とアイコンを持つので、同じ形で出せる。
# 使い方：json.partial! "api/shared/partner", record: 学生プロフィールか企業プロフィール

json.partner do
  json.id record.id
  json.name record.name
  json.partial! "api/shared/icon_url", record: record
end
