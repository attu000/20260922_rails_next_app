# scout_messages（スカウトメッセージ）。design/designs/データベース.md の 8-5。
# どのメッセージが、どのやりとり（募集×学生）のスカウト文かを持つ。
# 同じ企業が別の募集で2回スカウトすると、同じスレッドにスカウト文が2つ並ぶので、どの募集のスカウトかをここで表示できる
class CreateScoutMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :scout_messages do |t|
      # 1つのメッセージは1つのスカウトにだけ対応する
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      # 1つのやりとりにスカウト文は1つ
      t.references :candidacy, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
