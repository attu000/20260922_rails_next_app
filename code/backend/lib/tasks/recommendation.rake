# 推薦の集計の全体の作り直しを、待ち行列に積むコマンド。bin/rails recommendation:rebuild で動かす。
# Django の manage.py に自作のコマンドを足し、その中で Celery のタスクを .delay() するのにあたる。
# 実際に数え直すのは、実行係（Solid Queue）が取り出したとき（処理設計_類似度.md の 7-5「全体の作り直し」）
namespace :recommendation do
  desc "推薦の集計（件数・self_weight・項目数）を、全学生・全募集について元データから数え直すジョブを積む"
  task rebuild: :environment do
    RecommendationStatsRebuildJob.perform_later
    puts "推薦の集計の全体の作り直しを、待ち行列（#{RecommendationStatsRebuildJob.queue_name}）に積みました。実行係が順番に処理します"
  end
end
