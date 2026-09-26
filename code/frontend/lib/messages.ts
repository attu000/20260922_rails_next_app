// メッセージの型。Rails の app/views/api/{company,student}/message_threads/ と messages/ の JSON と同じ形
// （design/designs/API設計.md の 16-3-7 ㊱〜㊶）。企業・学生で同じ形（相手が学生か企業かだけが違う）。
// 空欄は null

// 相手。企業から見れば学生、学生から見れば企業
export type MessagePartner = {
  id: number;
  name: string;
  icon_url: string | null;
};

// ㊱㊴ スレッド一覧の1行
export type MessageThreadRow = {
  id: number;
  partner: MessagePartner;
  // 最後のメッセージの日時。メッセージがまだなければ（応募のマッチでできただけ）null
  last_message_at: string | null;
};

// ㊱㊴ スレッド一覧の返事。並び順は最後のメッセージの新しい順（Rails が並べる。PR221）
export type MessageThreadListResult = {
  items: MessageThreadRow[];
  pagination: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
};

// メッセージ1件（㊲㊵ の messages の要素。㊳㊶ 送信の返事も同じ形）
export type Message = {
  id: number;
  // 自分が送ったメッセージなら true（Rails が判定する）
  is_mine: boolean;
  body: string;
  created_at: string;
  // スカウト文のときだけ、どの募集のスカウトか。ふつうのメッセージなら null
  scout: { job_posting: { id: number; title: string } } | null;
};

// 学生が今マッチできるスカウト（㊵ の matchable_scouts の要素。PR222・PR223）。
// 押したら ㉜ POST /api/student/candidacies/:candidacy_id/match に送る
export type MatchableScout = {
  candidacy_id: number;
  job_posting: { id: number; title: string };
};

// ㊲㊵ チャット。
// マッチしている募集（matched_job_postings）は【仕上げ】で足す
export type MessageThreadDetail = {
  partner: MessagePartner;
  // 今送れるか（その相手とマッチ以降のやりとりが1つでもあるか）。Rails が判定する（権限_バリデーション.md の 17-2-3）
  can_send: boolean;
  // 古い順に全件
  messages: Message[];
  // 学生のチャット（㊵）だけが返す。今マッチできるスカウト（Rails が判定する）。企業のチャット（㊲）にはない
  matchable_scouts?: MatchableScout[];
};
