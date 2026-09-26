# スカウトメッセージ（design/designs/データベース.md の 8-5）。
# どのメッセージが、どのやりとり（募集×学生）のスカウト文かを持つ。
# 作るのはスカウトの送信（順6）だけ。「1つのやりとりにスカウト文は1つ」などの重複は、データベースの決まりで防ぐ
class ScoutMessage < ApplicationRecord
  belongs_to :message
  belongs_to :candidacy
end
