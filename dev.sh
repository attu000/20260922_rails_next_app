#!/usr/bin/env bash
# ハロー・インターン（仮）の開発用コマンド。
# 使い方：リポジトリのルートで bash dev.sh <コマンド>（例：bash dev.sh setup）
# Windows では Git Bash で実行する（PowerShell の bash は WSL の bash になり、Docker を使えないことがある）。
# 詳しくは design/designs/開発環境.md の 18-6

set -euo pipefail

# どこから実行しても、docker-compose.yml がある code/ フォルダで動かす
cd "$(dirname "$0")/code"

# Git Bash が「/ で始まる引数」を Windows のパスに書き換えるのを止める（Mac・Linux では何もしない）
export MSYS_NO_PATHCONV=1

usage() {
  cat <<'EOF'
使い方：bash dev.sh <コマンド>

  setup   最初の準備をして起動する（.env の作成、コンテナの作成、データベースの準備、起動）。何度実行してもよい
  start   起動する
  stop    止める（データは残る）
  reset   コンテナとデータをすべて消して、setup からやり直す（確認あり）
  test    Rails のテストを実行する
  lint    画面側（Next.js）の型のチェックと、コードの点検をする
  demo    仮のデータ（企業5社・募集20件・学生20人など）を入れる。何度実行してもよい
  rebuild 推薦の集計の全体の作り直しを待ち行列に積む（実行係の jobs が処理する）。不具合からの復旧などに使う
  logs    ログを出し続ける（例：bash dev.sh logs backend、ジョブは bash dev.sh logs jobs）。Ctrl+C で止める
  bench-load     速さの実測に使う測定用のデータを入れる（例：bash dev.sh bench-load small。small か medium）
  bench-measure  おすすめ順などの処理時間を測る（先に bench-load を実行しておく）
  bench-diagnose 近さの部品ごとに、相手の数を増やしたときの時間の増え方を測る（結果は code/backend/tmp/bench_diagnose.txt にも書く）
  help    この説明を出す
EOF
}

cmd_setup() {
  # 1. .env がなければ、見本から作る（すでにあれば触らない）
  if [ ! -f .env ]; then
    cp .env.example .env
    echo "code/.env を作りました（中身は code/.env.example と同じ）"
  fi

  # 2. コンテナを作る（初回は部品のインストールで数分かかる）
  docker compose build

  # 3. データベースを作り、テーブルを作り、試しのアカウントを入れる。
  #    Django の「データベースを作る → migrate → loaddata」と同じ。すでにあるものは作り直さない。
  #    db:prepare は、データベースがなければ作って設計図（schema.rb・queue_schema.rb）から表を作り、あれば未実行のマイグレーションを流す。
  #    ジョブの待ち行列のデータベースはマイグレーションのファイルを持たず設計図だけなので、db:migrate では表ができない（PR291）
  docker compose run --rm backend bin/rails db:prepare db:seed

  # 4. 起動する
  docker compose up -d

  cat <<'EOF'

起動しました。ブラウザで http://localhost:3000 を開いてください。
（開発用の起動なので、各画面を初めて開いたときは十数秒かかります）

試しのアカウント
  企業：company@example.com / password
  学生：student@example.com / password
EOF
}

cmd_start() {
  docker compose up -d
  echo "起動しました。ブラウザで http://localhost:3000 を開いてください。"
}

cmd_stop() {
  docker compose down
}

cmd_reset() {
  echo "データベースの中身と、入れた部品（gem・node_modules）をすべて消して、最初から作り直します。"
  read -r -p "よろしいですか？ (y/N) " answer
  if [ "$answer" != "y" ]; then
    echo "やめました。"
    exit 0
  fi
  # -v：ボリューム（データベースの中身、部品の置き場所）も消す
  docker compose down -v
  cmd_setup
}

cmd_test() {
  # -T：画面とのやりとり（TTY）を使わない。Git Bash でも動くようにするため
  docker compose run --rm -T backend bundle exec rspec
}

cmd_lint() {
  # 開発用サーバーが作る型のファイル（.next/dev/types）は、起動直後に2か所から同時に書かれて壊れることがある（PR305）。
  # それを消し、next typegen で型のファイルを別の場所（.next/types）に1回だけ作り直してから確かめる
  docker compose run --rm -T frontend sh -c "rm -rf .next/dev/types && npx next typegen && npx tsc --noEmit"
  docker compose run --rm -T frontend npm run lint
  echo "型のチェックと、コードの点検が通りました。"
}

cmd_demo() {
  # 仮のデータを入れる（code/backend/lib/tasks/demo.rake）。前回の仮のデータは消して作り直す。
  # 試しのアカウント（company@example.com など）と、画面から登録したアカウントは消さない
  docker compose run --rm -T backend bin/rails demo:load
}

cmd_rebuild() {
  # 推薦の集計の全体の作り直し（code/backend/lib/tasks/recommendation.rake）。
  # その場では数え直さず、応募のジョブと同じ待ち行列に積む。実行係（jobs のコンテナ）が順番に処理する
  docker compose run --rm -T backend bin/rails recommendation:rebuild
}

cmd_logs() {
  docker compose logs -f "$@"
}

cmd_bench_load() {
  # 速さの実測に使う、測定用のデータを入れる（code/backend/lib/tasks/bench.rake）。段階は small か medium（省略すると small）。
  # 前回の測定用のデータは消して作り直す。仮のデータ（demo）と試しのアカウントは消さない
  docker compose run --rm -T backend bin/rails "bench:load[${1:-small}]"
}

cmd_bench_measure() {
  # おすすめ順・応募のジョブ・全体の作り直しの処理時間を測る（技術構成.md の 9-4-1）
  docker compose run --rm -T backend bin/rails bench:measure
}

cmd_bench_diagnose() {
  # 近さの部品ごとに、相手の数を増やしたときの時間の増え方と実行計画を出す（code/backend/db/bench/diagnoser.rb）
  docker compose run --rm -T backend bin/rails bench:diagnose
}

command="${1:-help}"
shift || true

case "$command" in
  setup) cmd_setup ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  reset) cmd_reset ;;
  test) cmd_test ;;
  lint) cmd_lint ;;
  demo) cmd_demo ;;
  rebuild) cmd_rebuild ;;
  logs) cmd_logs "$@" ;;
  bench-load) cmd_bench_load "$@" ;;
  bench-measure) cmd_bench_measure ;;
  bench-diagnose) cmd_bench_diagnose ;;
  help | -h | --help) usage ;;
  *)
    echo "知らないコマンドです：$command"
    echo
    usage
    exit 1
    ;;
esac
