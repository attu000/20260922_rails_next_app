# candidacy_reasons（応募理由・マッチ理由）。design/designs/データベース.md の 8-5。
# 応募したとき・スカウトにマッチしたときに、最低1行作る（アプリで確認する）。マッチしていないスカウトのやりとりには行がない
#
# 目印（インデックス）は create_table の中に書く。取り消し（db:rollback）のときに、テーブルと一緒に消えるようにするため
class CreateCandidacyReasons < ActiveRecord::Migration[8.1]
  def change
    create_table :candidacy_reasons do |t|
      t.references :candidacy, null: false, foreign_key: true
      # 理由。12個の値と番号は CandidacyReason モデルの enum で明示する
      t.integer :reason, null: false

      t.timestamps

      # 同じやりとりに同じ理由を2回付けない
      t.index %i[candidacy_id reason], unique: true
    end
  end
end
