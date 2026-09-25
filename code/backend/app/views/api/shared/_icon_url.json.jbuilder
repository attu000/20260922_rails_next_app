# アイコンの URL を "icon_url" として出す部品。⑧⑨⑩⑮⑯⑰ と形A（/api/me）で使い回す。
# 使い方：json.partial! "api/shared/icon_url", record: 企業プロフィールか学生プロフィール
#
# 住所は /rails/active_storage/… で始まる。ブラウザからは Next.js の rewrites を通って Rails に届く（技術構成.md の 9-3）。
# アイコンがなければ null（画面側で既定の画像を出す。API設計.md の 16-3 形A）

if record.icon.attached?
  json.icon_url rails_blob_path(record.icon)
else
  json.icon_url nil
end
