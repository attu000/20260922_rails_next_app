# messages（メッセージ）。design/designs/データベース.md の 8-5。
# 種類に関係なく共通の「純粋なメッセージ」の表。スカウト文かどうかは scout_messages で持つ。
# 順6 ではスカウトを送るときだけ作り、メッセージを送る窓口は順7 で作る
class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      # 「スレッドで探す」だけの目印は作らない。下の (message_thread_id, created_at) の目印が、先頭の列で同じ役目を果たすため
      t.references :message_thread, null: false, foreign_key: true, index: false
      # 送った人（users の番号）。列の名前と行き先の表の名前が違うので、行き先を to_table で指定する
      t.references :sender_user, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps

      # チャットを時間の順に並べて出すため
      t.index %i[message_thread_id created_at]
    end
  end
end
