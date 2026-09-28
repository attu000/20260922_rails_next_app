// 通知の型。Rails の app/views/api/company/notifications/index.json.jbuilder の JSON と同じ形
// （design/designs/API設計.md の 16-3-8 ㊷）。空欄は null

// ㊷ 通知の一覧の1行
export type NotificationRow = {
  id: number;
  // 種類。今は「おすすめの学生」（recommended_student）だけ
  kind: string;
  // 本文。作ったときの文言で固定されている
  body: string;
  // 押したときの移動先（アプリ内のパス）。空欄なら押しても移動しない
  link_path: string | null;
  // 既読にした日時。null なら未読
  read_at: string | null;
  created_at: string;
};

// ㊷ 通知の一覧の返事。並び順は新しい順（Rails が並べる）
export type NotificationListResult = {
  items: NotificationRow[];
  pagination: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
};
