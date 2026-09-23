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
  logs    ログを出し続ける（例：bash dev.sh logs backend）。Ctrl+C で止める
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
  #    Django の「データベースを作る → migrate → loaddata」と同じ。すでにあるものは作り直さない
  docker compose run --rm backend bin/rails db:create db:migrate db:seed

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
  docker compose run --rm -T frontend npx tsc --noEmit
  docker compose run --rm -T frontend npm run lint
  echo "型のチェックと、コードの点検が通りました。"
}

cmd_logs() {
  docker compose logs -f "$@"
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
  logs) cmd_logs "$@" ;;
  help | -h | --help) usage ;;
  *)
    echo "知らないコマンドです：$command"
    echo
    usage
    exit 1
    ;;
esac
