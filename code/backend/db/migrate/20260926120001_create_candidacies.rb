# candidacies（やりとり：募集×学生）。design/designs/データベース.md の 8-5。
# 応募・スカウトのどちらから始まっても、この1行が「やりとり」になる。削除はせず、状態で管理する
#
# 目印（インデックス）と CHECK は create_table の中に書く。取り消し（db:rollback）のときに、テーブルと一緒に消えるようにするため
class CreateCandidacies < ActiveRecord::Migration[8.1]
  def change
    create_table :candidacies do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :student_profile, null: false, foreign_key: true

      # 発生元。application（応募）：0 ／ scout（スカウト）：1（番号は Candidacy モデルの enum で明示する）。作成後は変えない
      t.integer :origin, null: false
      # 状態。unmatched（未マッチ）：0 ／ matched（マッチ）：1 ／ declined（見送り）：2 ／ passed（合格）：3 ／ failed（不合格）：4
      t.integer :status, null: false, default: 0
      # マッチが成立した日時
      t.datetime :matched_at
      # 応募理由の組を12ビットで表したもの（candidacy_reasons の reason の番号 i をビット i に対応）。
      # 空欄＝理由なし（マッチしていないスカウト）。おすすめの計算を速くするための写しで、candidacy_reasons と同じトランザクションで書く。
      # limit: 2 で smallint になる
      t.integer :reason_mask, limit: 2

      # created_at が「やりとりが始まった日」（応募日・スカウト日）。一覧の並び順に使う
      t.timestamps

      # 同じ募集×学生のやりとりは1件だけ（権限_バリデーション.md の 17-2-1）
      t.index %i[job_posting_id student_profile_id], unique: true
      # 候補者一覧の募集別タブで使う
      t.index %i[job_posting_id status]
      # おすすめの計算で「応募理由があるやりとり」だけを読むときに使う（順12）。reason_mask が空でない行だけの部分インデックス
      t.index :student_profile_id, where: "reason_mask IS NOT NULL", name: "index_candidacies_on_student_profile_id_with_reasons"
      t.index :job_posting_id, where: "reason_mask IS NOT NULL", name: "index_candidacies_on_job_posting_id_with_reasons"
      # 12ビットの範囲（1〜4095）。空欄はこの条件の対象外
      t.check_constraint "reason_mask BETWEEN 1 AND 4095", name: "candidacies_reason_mask_range"
    end
  end
end
