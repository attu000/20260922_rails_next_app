// プチ職業体験の講座と自己分析の型。Rails の app/views/api/student/job_trials/ と self_analyses/ の JSON と同じ形
// （design/designs/API設計.md の 16-3-9 ㊺〜㊽）

// 講座の一覧の1行（㊺）
export type JobTrialRow = {
  id: number;
  title: string;
  job_middle_category_id: number;
  // 工程の表示順
  work_process_ids: number[];
  // 自分がその講座の自己分析を送っているか（修了済み。判定は Rails）
  completed: boolean;
};

// 講座の一覧（㊺）。ページ分けしない
export type JobTrialList = { items: JobTrialRow[] };

// 問題の選択肢。学生には key と本文だけが届く（正解と解説は ㊼ で答えるたびに届く）
export type JobTrialChoice = { key: string; body: string };

// ハードル1つ。解説と問題の文は Markdown
export type JobTrialHurdle = {
  id: number;
  name: string;
  overview: string;
  difficulty: string;
  tips: string;
  example: string;
  goal: string;
  question: string;
  choices: JobTrialChoice[];
};

// 自己分析（㊽ の返事。㊻ の self_analysis も同じ形）
export type SelfAnalysis = {
  job_trial_id: number;
  strength_hurdle_id: number;
  strength_reason: string;
  growth_hurdle_id: number;
  // "curiosity" など。表示名と 2-3 の問いは ⑦ の enums.growth_reason
  growth_reason: string;
  growth_detail: string;
  next_step: string;
  // 1-1 と 2-1 が同じハードルか（判定は Rails）
  same_hurdle: boolean;
  created_at: string;
  updated_at: string;
};

// 講座の中身と、自分の自己分析（㊻）
export type JobTrialDetail = {
  id: number;
  title: string;
  job_middle_category_id: number;
  work_process_ids: number[];
  // 「はじめに」の文（Markdown）
  intro: string;
  // 講座の中の順番
  hurdles: JobTrialHurdle[];
  // 自分の自己分析。なければ null（まだ修了していない）
  self_analysis: SelfAnalysis | null;
};

// 問題の正否の判定の返事（㊼）。explanation は選んだ選択肢の解説
export type JobTrialCheckResult = { correct: boolean; explanation: string };

// 企業向けの講座の中身（㊾）。学生向けと同じ形から自己分析を除き、選択肢に正解と解説を加えたもの（PR373）
export type CompanyJobTrialChoice = JobTrialChoice & { correct: boolean; explanation: string };
export type CompanyJobTrialHurdle = Omit<JobTrialHurdle, "choices"> & { choices: CompanyJobTrialChoice[] };
export type CompanyJobTrial = Omit<JobTrialDetail, "hurdles" | "self_analysis"> & { hurdles: CompanyJobTrialHurdle[] };

// 企業の学生詳細（㉓）の自己分析。画面は講座の中身を持たないので、講座名とハードルの名前が入っている
export type CompanySelfAnalysis = {
  job_trial: { id: number; title: string };
  strength_hurdle: { id: number; name: string };
  strength_reason: string;
  growth_hurdle: { id: number; name: string };
  // "curiosity" など。表示名と 2-3 の問いは ⑦ の enums.growth_reason
  growth_reason: string;
  growth_detail: string;
  next_step: string;
  // 1-1 と 2-1 が同じハードルか（「得意を伸ばしたい」と添える。判定は Rails）
  same_hurdle: boolean;
  // 修了した日（初めて送った日）と、最後に書き直した日
  created_at: string;
  updated_at: string;
};

// 自己分析のはじめの案内文（仮。サービス概要_コンセプト.md の 12-4）
export const SELF_ANALYSIS_GUIDE =
  "ここに書いた内容は、企業があなたのプロフィールとして読みます。あなたの良さが伝わるように、正直に、自分の言葉で書きましょう。";

// 自己分析の問いの文（仮。サービス概要_コンセプト.md の 12-4）。学生の入力（S12）、企業の講座の内容（C11）、
// 学生詳細のポップアップ（C6）の小見出しで共通に使う。
// 2-3 の深掘りの問いは、2-2 で選んだ理由ごとに違うので、⑦ の enums.growth_reason の detail_question を使う（PR397）
export const SELF_ANALYSIS_QUESTIONS = {
  // 1-1
  strength_hurdle: "いちばん得意だと感じたハードルはどれですか？",
  // 1-2
  strength_reason: "なぜそう感じたと思いますか？",
  strength_reason_note: "そのハードルの特徴と、自分の特徴や経験を結び付けて考えてみましょう。",
  // 2-1
  growth_hurdle: "今後、いちばん伸ばしてみたいと思ったハードルはどれですか？",
  // 2-2
  growth_reason: "そのハードルを伸ばしたいと思った理由に、いちばん近いものを選んでください。",
  // 2-4
  next_step: "そのハードルを伸ばすとしたら、次に何を知りたいですか。または、何をやってみたいですか。",
} as const;
