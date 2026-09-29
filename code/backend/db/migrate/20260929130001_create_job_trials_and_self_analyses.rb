# プチ職業体験の表4つ（design/designs/データベース.md の 8-5 I）。Phase 7 の順18。
# - job_trials（講座）・job_trial_hurdles（ハードル）・job_trial_work_processes（工程のタグ）：
#   db/job_trials/ の YAML から、初期データ（db/seeds.rb）の流れで読み込む。画面からは読むだけで、削除しない（PR383）
# - self_analyses（自己分析）：学生×講座に1件。書き直しは上書き（PR371）
# 募集×講座（job_posting_job_trials）は、使う順19 で作る。
# 外部キーは既定の動き（参照されている行は消せない）のまま。誤ってデータが消えないようにするため（技術構成.md の 9-5）
class CreateJobTrialsAndSelfAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :job_trials do |t|
      # YAML と行を結び付ける目印（例：qa-coupon）
      t.string :code, null: false, index: { unique: true }
      t.string :title, null: false
      # 講座の中分類（1つ。PR357）
      t.references :job_middle_category, null: false, foreign_key: true
      # 「はじめに」の文（Markdown。PR382）
      t.text :intro, null: false
      # 一覧の並び順
      t.integer :position, null: false

      t.timestamps
    end

    create_table :job_trial_hurdles do |t|
      t.references :job_trial, null: false, foreign_key: true, index: false
      # 例：understand。同じ講座の中で重複しない
      t.string :code, null: false
      # 講座の中の順番（YAML に書いた順）
      t.integer :position, null: false
      # ハードルの名前（「理解する」など）
      t.string :name, null: false
      # 概要・難しさ・コツ・具体例・ゴール・問題文（すべて Markdown）
      t.text :overview, null: false
      t.text :difficulty, null: false
      t.text :tips, null: false
      t.text :example, null: false
      t.text :goal, null: false
      t.text :question, null: false
      # 選択肢の並び。1つずつ key・body・correct・explanation を持つ（PR380）。問題と選択肢を別の表にしないのは、答えを記録しないため
      t.jsonb :choices, null: false

      t.timestamps

      # 「講座×code」で重複不可。先頭の列が講座なので、講座で探す目印も兼ねる
      t.index %i[job_trial_id code], unique: true
    end

    create_table :job_trial_work_processes do |t|
      t.references :job_trial, null: false, foreign_key: true, index: false
      t.references :work_process, null: false, foreign_key: true

      t.timestamps

      # UNIQUE(両方)：同じ講座に同じ工程を2回付けない。先頭の列が講座なので、講座で探す目印も兼ねる
      t.index %i[job_trial_id work_process_id], unique: true
    end

    create_table :self_analyses do |t|
      t.references :student_profile, null: false, foreign_key: true, index: false
      t.references :job_trial, null: false, foreign_key: true
      # 1-1 いちばん得意なハードル、2-1 いちばん伸ばしたいハードル
      t.references :strength_hurdle, null: false, foreign_key: { to_table: :job_trial_hurdles }
      t.references :growth_hurdle, null: false, foreign_key: { to_table: :job_trial_hurdles }
      # 1-2 得意だと感じた理由
      t.text :strength_reason, null: false
      # 2-2 伸ばしたい理由の種類。challenge：0／curiosity：1／importance：2／future：3／other：4。新しい値は末尾の番号で足す
      t.integer :growth_reason, null: false
      # 2-3 理由に応じた深掘り
      t.text :growth_detail, null: false
      # 2-4 次に知りたいこと・やってみたいこと
      t.text :next_step, null: false

      t.timestamps

      # 1人×1講座に1件（PR371）。先頭の列が学生なので、学生で探す目印も兼ねる
      t.index %i[student_profile_id job_trial_id], unique: true
    end
  end
end
