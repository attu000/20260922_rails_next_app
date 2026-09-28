# すべてのジョブの親（Active Job。design/designs/技術構成.md の 3章、処理設計_類似度.md の 7-5）
class ApplicationJob < ActiveJob::Base
  # perform_later を呼んだ時点でトランザクションの中にいたら、いちばん外側が確定するまで待ってから積む。取り消されたら積まない。
  # 待ち行列は別のデータベース（PR291）にあり、アプリのトランザクションに入らないので、
  # 確定前に積むと、実行係が「まだ保存されていないデータ」を読んだり、取り消されたデータについて動いたりするため。
  # Django の transaction.on_commit(lambda: task.delay(...)) を、すべてのジョブで自動で行うのにあたる
  self.enqueue_after_transaction_commit = true

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
