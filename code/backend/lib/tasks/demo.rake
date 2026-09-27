# 仮のデータ（デモ用）を入れるコマンド。bin/rails demo:load で動かす（bash dev.sh demo からも呼べる）。
# Django の manage.py に自作のコマンドを足すのにあたる。
# 中身は db/demo/content.rb、作る処理は db/demo/loader.rb。db/seeds.rb（マスタと試しのアカウント）とは分けている（PR264）
namespace :demo do
  desc "仮の企業5社・募集20件・学生20人と、やりとり・メッセージを入れる（開発用のデータベースだけ。何度実行してもよい）"
  task load: :environment do
    # テストや本番のデータベースに仮のデータが混ざらないよう、開発用でなければ止める
    abort "仮のデータは、開発用のデータベースでだけ入れられます（今は #{Rails.env}）" unless Rails.env.development?
    # マスタ（業界・職種など）は db/seeds.rb が入れる。なければ仮のデータを作れない
    abort "マスタがありません。先に bash dev.sh setup を実行してください" unless Industry.exists? && JobMiddleCategory.exists?

    require Rails.root.join("db/demo/loader").to_s

    begin
      counts = DemoLoader.load!
    rescue DemoLoader::Error => e
      abort "仮のデータを入れられませんでした（何も変わっていません）。#{e.message}"
    end

    puts <<~MESSAGE
      仮のデータを入れました：企業#{counts[:companies]}社、募集#{counts[:job_postings]}件、学生#{counts[:students]}人、やりとり#{counts[:candidacies]}件
      ログイン（パスワードはどれも #{DemoLoader::PASSWORD}）
        企業：#{DemoLoader::EMAIL_PREFIX}company1#{DemoLoader::EMAIL_DOMAIN} 〜 #{DemoLoader::EMAIL_PREFIX}company#{counts[:companies]}#{DemoLoader::EMAIL_DOMAIN}
        学生：#{DemoLoader::EMAIL_PREFIX}student1#{DemoLoader::EMAIL_DOMAIN} 〜 #{DemoLoader::EMAIL_PREFIX}student#{counts[:students]}#{DemoLoader::EMAIL_DOMAIN}
    MESSAGE
  end
end
