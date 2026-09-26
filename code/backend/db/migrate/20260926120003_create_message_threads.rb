# message_threads（スレッド：企業×学生）。design/designs/データベース.md の 8-5。
# 応募がマッチしたとき（順5）と、スカウトを送ったとき（順6）に、まだなければ作る（技術構成.md の 9-2）。
# メッセージ本体（messages）とスカウトメッセージ（scout_messages）は、使う順6・順7 で作る
#
# 目印（インデックス）は create_table の中に書く。取り消し（db:rollback）のときに、テーブルと一緒に消えるようにするため
class CreateMessageThreads < ActiveRecord::Migration[8.1]
  def change
    create_table :message_threads do |t|
      t.references :company_profile, null: false, foreign_key: true
      t.references :student_profile, null: false, foreign_key: true
      # 最後のメッセージの日時。スレッド一覧の並び替え用（順7）
      t.datetime :last_message_at

      t.timestamps

      # 企業×学生でスレッドは1本
      t.index %i[company_profile_id student_profile_id], unique: true
    end
  end
end
