# 速さの実測（design/designs/技術構成.md の 9-4-1）のコマンド。Django の manage.py に自作のコマンドを足すのにあたる。
#   bin/rails "bench:load[small]"  … 測定用のデータを入れる（small か medium。省略すると small）。bash dev.sh bench-load small からも呼べる
#   bin/rails bench:measure        … 場面ごとの処理時間を測って出す。bash dev.sh bench-measure からも呼べる
#   bin/rails bench:diagnose       … 部品ごとに、相手の数を増やしたときの時間の増え方を測る。bash dev.sh bench-diagnose からも呼べる
# データを作る処理は db/bench/loader.rb、測る処理は db/bench/measurer.rb、診断は db/bench/diagnoser.rb
namespace :bench do
  desc "測定用のデータ（small：学生100人・募集100件、medium：学生5,000人・募集1,000件）を入れる（開発用のデータベースだけ。何度実行してもよい）"
  task :load, [ :size ] => :environment do |_task, args|
    # 仮のデータと同じ守り：テストや本番のデータベースに混ざらないよう、開発用でなければ止める
    abort "測定用のデータは、開発用のデータベースでだけ入れられます（今は #{Rails.env}）" unless Rails.env.development?
    abort "マスタがありません。先に bash dev.sh setup を実行してください" unless Industry.exists? && JobMiddleCategory.exists?

    require Rails.root.join("db/bench/loader").to_s

    size = args[:size].presence || "small"
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      counts = BenchLoader.load!(size)
    rescue BenchLoader::Error => e
      abort "測定用のデータを入れられませんでした（何も変わっていません）。#{e.message}"
    end
    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    puts "測定用のデータ（#{size}）を入れました：企業#{counts[:companies]}社、募集#{counts[:job_postings]}件、" \
         "学生#{counts[:students]}人、応募#{counts[:candidacies]}件（#{seconds.round(1)}秒）"
    puts "ログイン（パスワードはどれも #{BenchLoader::PASSWORD}）：#{BenchLoader::EMAIL_PREFIX}student1#{BenchLoader::EMAIL_DOMAIN} など"
  end

  desc "おすすめ順・似たもののポップアップ・応募のジョブ・全体の作り直しの処理時間を測る（先に bench:load で測定用のデータを入れておく）"
  task measure: :environment do
    abort "測定は、開発用のデータベースでだけ行えます（今は #{Rails.env}）" unless Rails.env.development?

    require Rails.root.join("db/bench/loader").to_s
    require Rails.root.join("db/bench/measurer").to_s

    begin
      BenchMeasurer.measure
    rescue BenchMeasurer::Error => e
      abort e.message
    end
  end

  desc "内容の近さ・行動の近さ・近さ f の部品ごとに、相手の数を増やしたときの時間の増え方と実行計画を出す（先に bench:load で測定用のデータを入れておく）"
  task diagnose: :environment do
    abort "診断は、開発用のデータベースでだけ行えます（今は #{Rails.env}）" unless Rails.env.development?

    require Rails.root.join("db/bench/loader").to_s
    require Rails.root.join("db/bench/diagnoser").to_s

    begin
      BenchDiagnoser.diagnose
    rescue BenchDiagnoser::Error => e
      abort e.message
    end
  end
end
