# work_processes（工程のマスタ）から、planning（「企画・設計から関われる」の対象か）の列を消す。
# 募集検索の条件を「企画・設計から関われる」のチェック1つから、工程そのものを選ぶ形に作り直し（PR251）、使うところがなくなったため（PR252）。
# すでに実行した 20260927120003_create_work_processes.rb は書き換えず、消すマイグレーションを足す（手元のデータベースと食い違わないように）
class RemovePlanningFromWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    # 型・空欄不可・初期値も書いておく。取り消し（db:rollback）のときに、同じ列を作り直せるようにするため
    remove_column :work_processes, :planning, :boolean, null: false, default: false
  end
end
