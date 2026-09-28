# 推薦の集計の全体の作り直し（処理設計_類似度.md の 7-5「全体の作り直し」、技術構成.md の 9-4）。
# 全学生・全募集の集計（件数・self_weight・項目数のすべて）を、元データから数え直して上書きする。行がなければ作る。
# 使う場面：不具合からの復旧、集計に列を足したとき。ずれを直すための定期実行はしない（応募のたびに影響を受ける値をすべて数え直すため）。
#
# 呼び方は2つ
# - 手動のコマンド（bin/rails recommendation:rebuild）：待ち行列に積む（perform_later）。
#   応募のジョブ（InterestRecordedJob）と同じ待ち行列で1つずつ順番に動くので、同時に動いて古い値で上書きすることがない
# - 仮のデータ（db/demo/loader.rb）と試しのアカウント（db/seeds.rb）を入れたあと：その場で実行する（perform_now）。
#   画面の操作がない準備の時間なので、順番を気にしなくてよい
class RecommendationStatsRebuildJob < ApplicationJob
  queue_as :recommendation

  # 一度に数え直す番号の数。学生10万人を一度に渡すと、番号の一覧も SQL も大きくなりすぎるため
  BATCH_SIZE = 1000

  def perform
    # in_batches は、番号の順に BATCH_SIZE 件ずつ取り出す（Django の queryset.iterator(chunk_size=...) に近い）
    StudentProfile.in_batches(of: BATCH_SIZE) do |batch|
      ids = batch.ids
      StudentRecommendationStat.refresh_item_counts!(ids)
      StudentRecommendationStat.refresh_interests!(ids)
    end

    JobPosting.in_batches(of: BATCH_SIZE) do |batch|
      ids = batch.ids
      JobPostingRecommendationStat.refresh_item_counts!(ids)
      JobPostingRecommendationStat.refresh_interests!(ids)
    end
  end
end
