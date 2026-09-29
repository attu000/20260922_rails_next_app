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
