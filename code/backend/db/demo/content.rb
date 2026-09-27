# 仮のデータ（デモ用）の中身。作る処理は db/demo/loader.rb。
# 会社・人の名前はすべて架空。マスタ（業界・職種・技術など）は、db/seeds.rb の名前・コードで指す。
# 文章は、画面で見たときに「それらしい」と感じられる程度に書いている（PR263〜PR266）
module DemoContent
  # ── 企業（5社）──
  # key：募集ややりとりから会社を指すための名前
  COMPANIES = [
    {
      key: :edu,
      name: "株式会社ソラノマナビ",
      employee_size: "size_50_99",
      industries: [ "教育" ],
      business_types: [ "自社サービス（個人向け）" ],
      about: "「わからない」を、その日のうちに「わかった」に変える。をミッションに、高校生向けの学習アプリを作っています。" \
             "社員の半分がエンジニアで、職種をまたいで相談しながら進める文化があります。" \
             "週に一度、学生インターンも参加する社内勉強会を開いています。",
      business_description: "高校生向けの学習アプリ「ソラノート」を開発・運営しています。" \
                            "問題を解いた記録から苦手な単元を見つけ、一人ひとりに合った問題と解説を出します。" \
                            "現在は全国で約30万人の高校生が利用しています。"
    },
    {
      key: :logistics,
      name: "株式会社ハコビテック",
      employee_size: "size_10_49",
      industries: [ "物流・交通・モビリティ" ],
      business_types: [ "自社サービス（法人向け）" ],
      about: "物流の現場の「紙とExcel」をなくすために、2021年に創業したスタートアップです。" \
             "メンバーは全国に住んでいて、ほぼすべての仕事をオンラインで進めています。" \
             "決まったことは文章に残し、誰でも後から追えるようにしています。",
      business_description: "中小の運送会社向けに、配送の計画と進み具合の管理ができるクラウドサービス「ハコビボード」を提供しています。" \
                            "配送ルートを自動で組み、ドライバーのスマホとつながって、荷物がどこにあるかを一目で確認できます。"
    },
    {
      key: :medical,
      name: "クリニカ・ブリッジ株式会社",
      employee_size: "size_100_299",
      industries: [ "医療・ヘルスケア・介護" ],
      business_types: [ "自社サービス（法人向け）" ],
      about: "医療の現場と患者さんを、使いやすいシステムでつなぐ会社です。" \
             "扱うデータが大切なものなので、設計とテストに時間をかけ、丁寧に作ることを大事にしています。" \
             "大阪の本社には、医師や看護師の経験があるメンバーも在籍しています。",
      business_description: "クリニック向けの予約・Web問診のシステム「クリニカ予約」を開発・提供しています。" \
                            "全国の約2,000のクリニックで使われ、待ち時間の短縮と受付の負担を減らすことに役立っています。"
    },
    {
      key: :si,
      name: "株式会社イトグチシステムズ",
      employee_size: "size_300_999",
      industries: [ "業界を問わない業務ツール" ],
      business_types: [ "受託開発・SIer" ],
      about: "創業30年の、企業の業務システムを作る会社です。" \
             "製造・小売・自治体など、さまざまなお客さまの仕事を理解するところから関わります。" \
             "研修の仕組みが整っていて、未経験から始めた先輩も多く活躍しています。",
      business_description: "企業の在庫管理・受発注・勤怠管理などの業務システムを、要件定義から開発・運用まで一貫して請け負っています。" \
                            "最近は、古いシステムをクラウドに移す案件や、セキュリティ診断の依頼が増えています。"
    },
    {
      key: :game,
      name: "株式会社ポコピコスタジオ",
      employee_size: "size_10_49",
      industries: [ "ゲーム" ],
      business_types: [ "自社サービス（個人向け）" ],
      about: "京都にある、少人数のゲームスタジオです。" \
             "「通勤電車の5分を、ちょっと楽しく」をテーマに、手軽に遊べるスマホゲームを作っています。" \
             "企画会議には職種に関係なく誰でも参加でき、インターン生のアイデアが採用されたこともあります。",
      business_description: "スマホ向けパズルゲーム「ポコピコパズル」（累計150万ダウンロード）を開発・運営しています。" \
                            "毎月のイベントの企画・開発と、遊ばれ方のデータをもとにした改善を続けています。"
    }
  ].freeze

  # ── 募集（1社4件、20件）──
  # key：やりとりから募集を指すための名前。status は published（掲載中）／unpublished（非公開）／closed（終了）。
  # jobs・processes は [メイン, サブ（関われる）] の組。職種は中分類のコード、工程と技術は名前で書く。
  # start_month は「今月から何か月後か」（nil は随時）。culture は [進め方, 新しさ, 周囲との関わり, 決め手, 職場の雰囲気]（−2〜2）
  POSTINGS = [
    # ソラノマナビ（教育）
    {
      key: :edu_frontend, company: :edu, status: :published,
      title: "学習アプリのフロントエンド開発インターン",
      internship_details: "学習アプリ「ソラノート」のWeb版で、問題を解く画面や学習の記録を見る画面の開発を担当していただきます。" \
                          "デザイナーが Figma で作った案をもとに、React と TypeScript で実装し、エンジニアのレビューを受けてリリースするまでを経験できます。" \
                          "慣れてきたら、利用者の声をもとにした改善の提案もお任せします。",
      growth: "数十万人が使う画面を、自分の手で改善する経験ができます。コンポーネントの設計やテストの書き方など、チーム開発の基本が身につきます。",
      requirements: "React または Vue.js で、何か1つ画面を作ったことがある方",
      preferred_requirements: "TypeScript を使ったことがある方\nデザインや使いやすさに興味がある方",
      jobs: [ %w[1-1], %w[1-3] ], processes: [ [ "実装" ], [ "設計", "テスト・評価" ] ],
      technologies: [ "TypeScript", "React", "Next.js", "Figma", "Git" ],
      hourly_wage: 1600, days: 3, hours: 4, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "週1回（水曜）は出社", prefecture: "東京都", work_location_note: "渋谷駅から徒歩7分",
      weekend_ok: false, work_note: "試験期間中は稼働を減らせます",
      culture: [ -1, -1, 1, 1, 0 ]
    },
    {
      key: :edu_data, company: :edu, status: :published,
      title: "学習データ分析インターン",
      internship_details: "生徒がどの問題でつまずいているかを、解答の記録から分析していただきます。" \
                          "SQL でデータを取り出し、Python で集計・可視化して、問題の作り手や企画のメンバーに改善案として伝えるところまでが仕事です。",
      growth: "実際のサービスのデータを使い、分析の結果が企画に反映されるところまで見届けられます。",
      requirements: "Python でデータの集計をしたことがある方",
      preferred_requirements: "SQL を書いたことがある方\n統計の基礎（平均・分散・検定など）を学んだことがある方",
      jobs: [ %w[2-3], %w[2-4] ], processes: [ [ "分析・モデル開発・実験" ], [ "データ収集・整備" ] ],
      technologies: [ "Python", "SQL", "PostgreSQL", "Google Cloud" ],
      hourly_wage: 1500, days: 2, hours: 4, months: 3, start_month: 1,
      work_style: "full_remote", work_style_note: nil, prefecture: nil, work_location_note: nil,
      weekend_ok: false, work_note: nil,
      culture: [ 0, 0, 1, -2, 1 ]
    },
    {
      key: :edu_llm, company: :edu, status: :published,
      title: "生成AIを使った解説機能の開発インターン",
      internship_details: "生徒がつまずいた問題に対して、生成AIがその生徒に合わせた解説を出す新機能を開発しています。" \
                          "プロンプトの設計、回答の良し悪しを測る仕組みづくり、API の実装まで、小さなチームで幅広く関わっていただきます。",
      growth: "生成AIを実際のサービスに組み込むときの難しさ（正確さ・費用・速さ）を、手を動かしながら学べます。",
      requirements: "Python で API を呼ぶプログラムを書いたことがある方",
      preferred_requirements: "生成AIの API を使って何か作ったことがある方\n教育に関心がある方",
      jobs: [ %w[2-1], %w[1-2] ], processes: [ [ "実装" ], [ "企画・要件定義", "テスト・評価" ] ],
      technologies: [ "Python", "FastAPI", "TypeScript", "AWS" ],
      hourly_wage: 1800, days: 3, hours: 5, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "月2回の出社日あり", prefecture: "東京都", work_location_note: "渋谷駅から徒歩7分",
      weekend_ok: false, work_note: nil,
      culture: [ -2, -2, 0, 1, 0 ]
    },
    {
      key: :edu_app, company: :edu, status: :unpublished,
      title: "スマホアプリ（Flutter）開発インターン",
      internship_details: "学習アプリのスマホ版を Flutter で作り直すプロジェクトに参加していただきます。（募集の準備中です）",
      growth: "1つのコードで iPhone と Android の両方に出すアプリの作り方を学べます。",
      requirements: "スマホアプリを作ってみたい方",
      preferred_requirements: nil,
      jobs: [ %w[1-4], [] ], processes: [ [ "実装" ], [] ],
      technologies: [ "Dart", "Flutter", "Firebase" ],
      hourly_wage: 1500, days: 2, hours: 4, months: 3, start_month: 2,
      work_style: "onsite", work_style_note: nil, prefecture: "東京都", work_location_note: "渋谷駅から徒歩7分",
      weekend_ok: false, work_note: nil,
      culture: [ -1, -1, 1, 0, 0 ]
    },

    # ハコビテック（物流）
    {
      key: :logi_api, company: :logistics, status: :published,
      title: "配送ルート計算のAPI開発インターン",
      internship_details: "配送先の住所と荷物の量から、効率のよい配送ルートを計算する API の開発に参加していただきます。" \
                          "計算の速さと正確さを両立させるための改善や、計算結果を運送会社の画面に返す部分の実装が中心です。",
      growth: "現場の困りごとを、アルゴリズムとデータで解決する経験ができます。設計の相談にも最初から参加できます。",
      requirements: "Python で何かしらのプログラムを書いたことがある方",
      preferred_requirements: "データベースを使ったアプリを作ったことがある方\nアルゴリズムに興味がある方",
      jobs: [ %w[1-2], %w[2-3] ], processes: [ [ "実装" ], [ "設計" ] ],
      technologies: [ "Python", "FastAPI", "PostgreSQL", "Docker" ],
      hourly_wage: 1700, days: 3, hours: 4, months: 6, start_month: nil,
      work_style: "full_remote", work_style_note: nil, prefecture: nil, work_location_note: nil,
      weekend_ok: true, work_note: "働く時間帯は自由です（週1回、夕方にオンラインの定例あり）",
      culture: [ -1, 0, -1, -2, 1 ]
    },
    {
      key: :logi_fullstack, company: :logistics, status: :published,
      title: "管理画面のフルスタック開発インターン",
      internship_details: "運送会社の事務の方が使う管理画面の開発を、画面から API まで通して担当していただきます。" \
                          "Ruby on Rails と React で作られていて、要望を聞いてから小さく作って出すまでを、1〜2週間の単位で繰り返します。",
      growth: "画面と裏側の両方を経験し、1つの機能を最初から最後まで作り切る力がつきます。",
      requirements: "Web アプリを1つ作ったことがある方（言語は問いません）",
      preferred_requirements: "Ruby on Rails または React の経験がある方",
      jobs: [ %w[1-3], %w[1-1 1-2] ], processes: [ [ "実装" ], [ "設計", "リリース・本番導入" ] ],
      technologies: [ "Ruby", "Ruby on Rails", "TypeScript", "React", "PostgreSQL" ],
      hourly_wage: 1600, days: 2, hours: 5, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "最初の1週間だけ出社", prefecture: "福岡県", work_location_note: "博多駅から徒歩5分",
      weekend_ok: false, work_note: nil,
      culture: [ -2, -1, 0, -1, -1 ]
    },
    {
      key: :logi_infra, company: :logistics, status: :published,
      title: "クラウド基盤・自動化インターン",
      internship_details: "サービスを動かしている AWS の環境を、Terraform でコードとして管理する取り組みを進めています。" \
                          "手作業で行っている作業の自動化や、監視の見直しを一緒に進めていただきます。",
      growth: "本番のサービスを支えるクラウドの仕組みを、実際に触りながら学べます。",
      requirements: "Linux のコマンド操作に抵抗がない方",
      preferred_requirements: "AWS や Docker を触ったことがある方",
      jobs: [ %w[3-1], %w[3-3] ], processes: [ [ "構築・自動化" ], [ "運用・改善", "監視・障害対応" ] ],
      technologies: [ "AWS", "Terraform", "Docker", "GitHub Actions", "Linux" ],
      hourly_wage: 1800, days: 2, hours: 6, months: 6, start_month: 1,
      work_style: "full_remote", work_style_note: nil, prefecture: nil, work_location_note: nil,
      weekend_ok: true, work_note: nil,
      culture: [ 1, -1, -1, -1, 2 ]
    },
    {
      key: :logi_viz, company: :logistics, status: :closed,
      title: "配送データの可視化インターン",
      internship_details: "配送の記録をグラフにまとめ、運送会社向けの月次レポートを作る仕組みを作っていただきました。（募集は終了しました）",
      growth: "データを「伝わる形」にまとめる力がつきます。",
      requirements: "Python を使ったことがある方",
      preferred_requirements: nil,
      jobs: [ %w[2-3], [] ], processes: [ [ "分析・モデル開発・実験" ], [] ],
      technologies: [ "Python", "SQL" ],
      hourly_wage: 1400, days: 2, hours: 3, months: 3, start_month: -3,
      work_style: "full_remote", work_style_note: nil, prefecture: nil, work_location_note: nil,
      weekend_ok: true, work_note: nil,
      culture: [ 0, 0, 0, -1, 1 ]
    },

    # クリニカ・ブリッジ（医療）
    {
      key: :med_backend, company: :medical, status: :published,
      title: "予約システムのバックエンド開発インターン",
      internship_details: "クリニック向け予約システムの、予約の受付や通知を行う部分の開発を担当していただきます。" \
                          "医療のデータを扱うため、仕様の確認とテストを丁寧に行う進め方です。先輩エンジニアがついて、設計の考え方から教えます。",
      growth: "止まってはいけないシステムを、どう設計しテストするかを学べます。",
      requirements: "Java または他のオブジェクト指向の言語で、プログラムを書いたことがある方",
      preferred_requirements: "SQL を書いたことがある方\nテストコードを書いたことがある方",
      jobs: [ %w[1-2], %w[4-1] ], processes: [ [ "実装" ], [ "テスト・評価" ] ],
      technologies: [ "Java", "Spring Boot", "MySQL", "AWS" ],
      hourly_wage: 1600, days: 3, hours: 5, months: 9, start_month: nil,
      work_style: "partial_remote", work_style_note: "週2回は出社", prefecture: "大阪府", work_location_note: "本町駅から徒歩3分",
      weekend_ok: false, work_note: nil,
      culture: [ 2, 1, 1, -1, 1 ]
    },
    {
      key: :med_qa, company: :medical, status: :published,
      title: "品質保証・テスト自動化インターン",
      internship_details: "リリース前のテストの計画づくりと、手作業で行っているテストの自動化を担当していただきます。" \
                          "不具合を見つけたら、開発者と一緒に原因を調べ、再発を防ぐ方法まで考えます。",
      growth: "「品質をどう守るか」を仕組みで考える力がつきます。どの職種に進んでも役立つ経験です。",
      requirements: "プログラミングの授業を受けたことがある方",
      preferred_requirements: "細かい違いに気づくのが得意な方",
      jobs: [ %w[4-1], %w[3-3] ], processes: [ [ "テスト・評価" ], [ "テスト計画・リスク評価" ] ],
      technologies: [ "TypeScript", "GitHub Actions" ],
      hourly_wage: 1400, days: 2, hours: 4, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "週1回は出社", prefecture: "大阪府", work_location_note: "本町駅から徒歩3分",
      weekend_ok: false, work_note: nil,
      culture: [ 2, 1, 1, -1, 1 ]
    },
    {
      key: :med_ml, company: :medical, status: :published,
      title: "問診データの機械学習インターン",
      internship_details: "Web問診の回答から、受診の前に確認しておくべき点を医師に知らせる仕組みの研究開発です。" \
                          "データの前処理、モデルの作成と評価、社内への報告までを、研究者の社員と一緒に進めていただきます。",
      growth: "研究で学んだ機械学習を、実際の医療の現場の課題に当てはめる経験ができます。学会発表を目指すこともできます。",
      requirements: "Python で機械学習のモデルを作ったことがある方",
      preferred_requirements: "論文を読んで手法を試したことがある方\n長期（1年以上）で関われる方",
      jobs: [ %w[2-2], %w[2-5] ], processes: [ [ "分析・モデル開発・実験" ], [ "課題設定", "発表・論文化" ] ],
      technologies: [ "Python", "PyTorch" ],
      hourly_wage: 1900, days: 2, hours: 4, months: 12, start_month: nil,
      work_style: "onsite", work_style_note: nil, prefecture: "大阪府", work_location_note: "本町駅から徒歩3分",
      weekend_ok: false, work_note: "研究室の予定に合わせて調整できます",
      culture: [ 1, -1, -1, -2, 2 ]
    },
    {
      key: :med_it, company: :medical, status: :published,
      title: "社内ITサポートインターン",
      internship_details: "社員が使うパソコンやアカウントの準備、社内ネットワークの管理、IT の問い合わせ対応を担当していただきます。" \
                          "よくある問い合わせは手順書にまとめ、自動化できるものは自動化していきます。",
      growth: "会社の IT がどう動いているかを、幅広く知ることができます。",
      requirements: "パソコンの設定などを調べて解決するのが好きな方",
      preferred_requirements: "Linux を触ったことがある方",
      jobs: [ %w[4-5], %w[3-4] ], processes: [ [ "運用・改善" ], [] ],
      technologies: [ "Linux" ],
      hourly_wage: 1200, days: 3, hours: 4, months: 3, start_month: nil,
      work_style: "onsite", work_style_note: nil, prefecture: "大阪府", work_location_note: "本町駅から徒歩3分",
      weekend_ok: false, work_note: nil,
      culture: [ 1, 1, 2, 0, 0 ]
    },

    # イトグチシステムズ（受託）
    {
      key: :si_system, company: :si, status: :published,
      title: "業務システムの受託開発インターン",
      internship_details: "製造業のお客さま向けの在庫管理システムの開発チームに参加していただきます。" \
                          "設計書をもとにした画面と処理の実装、テストの作成が中心です。お客さまとの打ち合わせに同席することもできます。",
      growth: "お客さまの業務を理解してシステムに落とし込む、受託開発ならではの流れを経験できます。",
      requirements: "Java・C# など、いずれかの言語でプログラムを書いたことがある方",
      preferred_requirements: "SQL を書いたことがある方",
      jobs: [ %w[1-5], %w[1-2] ], processes: [ [ "実装" ], [ "設計", "テスト・評価" ] ],
      technologies: [ "Java", "C#", "SQL" ],
      hourly_wage: 1500, days: 3, hours: 6, months: 6, start_month: 1,
      work_style: "onsite", work_style_note: nil, prefecture: "愛知県", work_location_note: "名古屋駅から徒歩10分",
      weekend_ok: false, work_note: "最初の2週間は研修です",
      culture: [ 2, 2, 2, -1, 0 ]
    },
    {
      key: :si_pdm, company: :si, status: :published,
      title: "要件定義から関わるPdMアシスタント",
      internship_details: "お客さまへのヒアリングに同席し、困りごとを整理して「何を作るか」を決める仕事を手伝っていただきます。" \
                          "議事録や要件の資料の作成、画面の簡単な案づくり、開発チームへの説明まで幅広く関わります。",
      growth: "技術と業務の両方を理解して、人と人をつなぐ力がつきます。",
      requirements: "人の話を聞いて整理するのが好きな方",
      preferred_requirements: "プログラミングの経験がある方（簡単なもので構いません）",
      jobs: [ %w[4-4], %w[1-5] ], processes: [ [ "企画・要件定義" ], [ "設計" ] ],
      technologies: [ "Figma", "SQL" ],
      hourly_wage: 1500, days: 2, hours: 4, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "お客さま訪問の日は出社", prefecture: "東京都", work_location_note: "品川駅から徒歩8分",
      weekend_ok: false, work_note: nil,
      culture: [ 0, 1, 2, 1, -1 ]
    },
    {
      key: :si_security, company: :si, status: :published,
      title: "セキュリティ診断アシスタント",
      internship_details: "お客さまの Web サービスに弱いところがないかを調べる、セキュリティ診断の補助をしていただきます。" \
                          "診断ツールの操作、結果の確認、報告書の作成を、専門のエンジニアと一緒に行います。",
      growth: "攻撃する側の考え方を知り、安全なシステムの作り方が身につきます。",
      requirements: "Web の仕組み（HTTP など）を学んだことがある方",
      preferred_requirements: "CTF に参加したことがある方\nPython で簡単なツールを作ったことがある方",
      jobs: [ %w[4-2], %w[3-2] ], processes: [ [ "テスト・評価" ], [ "テスト計画・リスク評価", "監視・障害対応" ] ],
      technologies: [ "Python", "Linux" ],
      hourly_wage: 1700, days: 2, hours: 5, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "週1回は出社", prefecture: "東京都", work_location_note: "品川駅から徒歩8分",
      weekend_ok: false, work_note: nil,
      culture: [ 2, 1, 1, -1, 2 ]
    },
    {
      key: :si_network, company: :si, status: :unpublished,
      title: "ネットワーク構築インターン",
      internship_details: "自治体のお客さま向けの、庁内ネットワークの構築を手伝っていただく予定です。（募集の準備中です）",
      growth: "ネットワークの設計と構築の基本を学べます。",
      requirements: "ネットワークに興味がある方",
      preferred_requirements: nil,
      jobs: [ %w[3-4], [] ], processes: [ [ "構築・自動化" ], [] ],
      technologies: [ "Linux" ],
      hourly_wage: 1400, days: 3, hours: 8, months: 6, start_month: 2,
      work_style: "onsite", work_style_note: nil, prefecture: "東京都", work_location_note: "品川駅から徒歩8分",
      weekend_ok: false, work_note: nil,
      culture: [ 2, 2, 1, 0, 0 ]
    },

    # ポコピコスタジオ（ゲーム）
    {
      key: :game_client, company: :game, status: :published,
      title: "パズルゲームのクライアント開発インターン",
      internship_details: "「ポコピコパズル」の毎月のイベントで使う、新しいステージや演出の開発を担当していただきます。" \
                          "企画と相談しながら Unity で作り、社内で遊んでもらって直す、を繰り返します。",
      growth: "自分が作ったステージを、たくさんの人に遊んでもらう経験ができます。",
      requirements: "Unity でゲームを作ったことがある方（完成していなくても構いません）",
      preferred_requirements: "C# に慣れている方\nゲームのアイデアを考えるのが好きな方",
      jobs: [ %w[1-6], %w[1-4] ], processes: [ [ "実装" ], [ "テスト・評価" ] ],
      technologies: [ "C#", "Unity", "Git" ],
      hourly_wage: 1500, days: 3, hours: 5, months: 6, start_month: nil,
      work_style: "partial_remote", work_style_note: "週2回は出社", prefecture: "京都府", work_location_note: "烏丸御池駅から徒歩4分",
      weekend_ok: true, work_note: nil,
      culture: [ -2, -1, 1, 1, -2 ]
    },
    {
      key: :game_server, company: :game, status: :published,
      title: "ゲームサーバー開発インターン",
      internship_details: "ランキングやイベントの報酬など、ゲームのサーバー側の機能を Go で開発していただきます。" \
                          "イベントの開始時にアクセスが集中しても落ちないよう、負荷の試験や改善にも取り組みます。",
      growth: "たくさんの人が同時に使うサーバーを、どう作りどう守るかを学べます。",
      requirements: "何かしらの言語で Web の API を作ったことがある方",
      preferred_requirements: "Go や Redis を触ったことがある方",
      jobs: [ %w[1-2], %w[3-1] ], processes: [ [ "実装" ], [ "構築・自動化", "運用・改善" ] ],
      technologies: [ "Go", "Redis", "Google Cloud", "Docker" ],
      hourly_wage: 1700, days: 2, hours: 4, months: 6, start_month: nil,
      work_style: "full_remote", work_style_note: nil, prefecture: nil, work_location_note: nil,
      weekend_ok: true, work_note: nil,
      culture: [ -1, -2, 0, 0, -1 ]
    },
    {
      key: :game_data, company: :game, status: :published,
      title: "プレイデータ分析インターン",
      internship_details: "どのステージで遊ぶのをやめてしまう人が多いかなど、プレイの記録を分析して、ゲームの改善案を企画のメンバーに提案していただきます。",
      growth: "分析の結果がゲームのバランス調整に使われ、数字が変わるところまで見届けられます。",
      requirements: "SQL または Python でデータを集計したことがある方",
      preferred_requirements: "ゲームが好きな方",
      jobs: [ %w[2-3], %w[4-4] ], processes: [ [ "分析・モデル開発・実験" ], [ "課題設定" ] ],
      technologies: [ "SQL", "Python", "Google Cloud" ],
      hourly_wage: 1500, days: 2, hours: 3, months: 3, start_month: nil,
      work_style: "full_remote", work_style_note: nil, prefecture: nil, work_location_note: nil,
      weekend_ok: true, work_note: nil,
      culture: [ -1, 0, 1, -2, 0 ]
    },
    {
      key: :game_vr, company: :game, status: :closed,
      title: "VRデモの試作インターン",
      internship_details: "展示会で見せる VR のデモを試作していただきました。（募集は終了しました）",
      growth: "新しい表現を試す楽しさを味わえます。",
      requirements: "Unity に興味がある方",
      preferred_requirements: nil,
      jobs: [ %w[1-6], %w[4-3] ], processes: [ [ "実装" ], [] ],
      technologies: [ "Unity", "C#" ],
      hourly_wage: 1400, days: 2, hours: 4, months: 3, start_month: -2,
      work_style: "onsite", work_style_note: nil, prefecture: "京都府", work_location_note: "烏丸御池駅から徒歩4分",
      weekend_ok: true, work_note: nil,
      culture: [ -2, -2, 0, 1, -1 ]
    }
  ].freeze

  # ── 学生のタイプ ──
  # タイプごとに、自己PR（強み・向いていないこと・この先やりたいこと）とプログラミング歴を2通りずつ書く。
  # skills は [技術の名前, 年数, レベル]。技術のマスタにない名前は「その他」の行になる
  STUDENT_TYPES = {
    frontend: {
      jobs: %w[1-1 1-3], industries: [ "教育", "エンタメ・メディア" ],
      profiles: [
        {
          strength: "大学のサークルで、部員の出欠を管理するアプリを React で作り、今は20人ほどが毎週使っています。" \
                    "使っている人の声を聞いて、画面を少しずつ直していくのが得意です。Figma で画面の案を作ってから実装するようにしています。",
          weakness: "細かい見た目にこだわりすぎて、締め切りがぎりぎりになることがあります。最近は、先に全体を動く状態にしてから整えるよう意識しています。",
          future: "たくさんの人が毎日使うサービスで、使いやすさを数字で確かめながら改善する経験を積みたいです。将来はフロントエンドの設計ができるエンジニアになりたいです。",
          skills: [ [ "TypeScript", 1.5, "v3" ], [ "React", 1.5, "v3" ], [ "Next.js", 0.5, "v2" ], [ "Figma", 1, "v2" ], [ "Git", 1.5, "v2" ] ]
        },
        {
          strength: "個人開発で、日本の城をめぐった記録を残す Web アプリを作って公開しています。" \
                    "地図の表示やスマホでの見やすさなど、触って気持ちのよい画面を作ることに一番やりがいを感じます。",
          weakness: "データベースやサーバーなど裏側の仕組みはまだ自信がなく、チュートリアルをなぞった程度です。",
          future: "実務のコードレビューを受けて、読みやすいコードを書く力を伸ばしたいです。画面だけでなく API の作りも理解して、フルスタックに近づきたいです。",
          skills: [ [ "JavaScript", 2, "v3" ], [ "Vue.js", 1, "v2" ], [ "TypeScript", 0.5, "v1" ], [ "Firebase", 0.5, "v2" ] ]
        }
      ]
    },
    backend: {
      jobs: %w[1-2 1-3 1-5], industries: [ "物流・交通・モビリティ", "業界を問わない業務ツール" ],
      profiles: [
        {
          strength: "授業のチーム開発で、Ruby on Rails を使った図書の貸し出し管理システムのバックエンドを担当しました。" \
                    "テーブルの設計から API、テストまでを書き、メンバーが使いやすいように説明の資料も用意しました。",
          weakness: "人前で話すのが得意ではなく、会議で意見を言うまでに時間がかかります。事前にメモを用意して臨むようにしています。",
          future: "多くの利用者がいるサービスで、データが増えても遅くならない仕組みを作る経験をしたいです。",
          skills: [ [ "Ruby", 1.5, "v3" ], [ "Ruby on Rails", 1, "v2" ], [ "PostgreSQL", 1, "v2" ], [ "Docker", 0.5, "v1" ], [ "Git", 1.5, "v2" ] ]
        },
        {
          strength: "研究室で、実験データを集める仕組みを Python の FastAPI で作り、先輩たちに使ってもらっています。" \
                    "困っていることを聞いて、仕組みで解決する流れが好きです。",
          weakness: "画面のデザインは苦手で、見た目は最低限になりがちです。",
          future: "物流や業務の効率化のように、目に見えにくいけれど多くの人の役に立つ仕組みに関わりたいです。Go にも挑戦したいと考えています。",
          skills: [ [ "Python", 2.5, "v3" ], [ "FastAPI", 1, "v2" ], [ "SQL", 1, "v2" ], [ "Go", 0.5, "v1" ], [ "Linux", 1, "v2" ] ]
        }
      ]
    },
    data_ai: {
      jobs: %w[2-2 2-3 2-1], industries: [ "医療・ヘルスケア・介護", "金融・保険" ],
      profiles: [
        {
          strength: "統計の授業をきっかけにデータ分析に興味を持ち、データ分析のコンペに3回参加しました。" \
                    "仮説を立ててデータで確かめ、結果をグラフにまとめて伝えるところまでやり切るのが得意です。",
          weakness: "結果にこだわるあまり、分析の手を広げすぎてしまうことがあります。",
          future: "実際の事業のデータを使って、意思決定につながる分析をしてみたいです。医療のように社会的な意味の大きい分野に関心があります。",
          skills: [ [ "Python", 2, "v3" ], [ "SQL", 1.5, "v2" ], [ "R", 1, "v2" ], [ "PyTorch", 0.5, "v1" ] ]
        },
        {
          strength: "研究で画像認識のモデルを PyTorch で作っていて、論文の手法を再現して精度を比べる実験をしています。" \
                    "うまくいかない原因を、一つずつ切り分けて調べるのが得意です。",
          weakness: "作業の見積もりが甘く、実験が予定より長引くことがあります。",
          future: "研究で身につけた機械学習の知識を、実際のサービスで使われる形にする経験を積みたいです。",
          skills: [ [ "Python", 3, "v3" ], [ "PyTorch", 1.5, "v3" ], [ "TensorFlow", 0.5, "v1" ], [ "Linux", 1.5, "v2" ] ]
        }
      ]
    },
    infra: {
      jobs: %w[3-1 3-2 3-3], industries: [ "業界を問わない業務ツール", "物流・交通・モビリティ" ],
      profiles: [
        {
          strength: "自宅のサーバーで Linux を動かし、家族の写真を共有する仕組みを作って2年ほど運用しています。" \
                    "止まったときに原因を調べて直すのが楽しく、監視の仕組みも自分で入れました。",
          weakness: "新しいことを始めるとき、全体を理解してからでないと手が動かないことがあります。",
          future: "クラウドで、たくさんの人が使うサービスを止めずに動かす仕事を経験したいです。",
          skills: [ [ "Linux", 2, "v3" ], [ "Docker", 1, "v2" ], [ "AWS", 0.5, "v2" ], [ "Terraform", 0.5, "v1" ], [ "GitHub Actions", 0.5, "v1" ] ]
        },
        {
          strength: "学園祭の Web サイトを AWS で公開し、当日のアクセスが増えても落ちないよう準備しました。" \
                    "作業を手順書にまとめて、次の年の担当に引き継いでいます。",
          weakness: "コードを書く量はまだ少なく、アプリの開発経験は浅いです。",
          future: "作業の自動化を進めて、開発する人が楽になる仕組みを作れるようになりたいです。",
          skills: [ [ "AWS", 1, "v2" ], [ "Linux", 1, "v2" ], [ "Python", 1, "v2" ], [ "Docker", 0.5, "v1" ] ]
        }
      ]
    },
    game: {
      jobs: %w[1-6 1-4], industries: [ "ゲーム", "エンタメ・メディア" ],
      profiles: [
        {
          strength: "Unity でスマホ向けのアクションゲームを作り、ストアで公開しました。" \
                    "遊んでくれた人の感想を見て、難しさの調整を何度も繰り返しました。",
          weakness: "ゲーム以外の分野の技術にはあまり触れてこなかったので、知識に偏りがあります。",
          future: "チームでゲームを作り、企画からリリースまでの流れを実際に経験したいです。",
          skills: [ [ "C#", 2, "v3" ], [ "Unity", 2, "v3" ], [ "Git", 1, "v2" ], [ "Blender", 1, "v2" ] ]
        },
        {
          strength: "ゲーム制作サークルで、プログラマーとして3本の作品の開発に関わりました。" \
                    "デザイナーやサウンドの担当と相談しながら、仕様を決めていくのが得意です。",
          weakness: "C++ は授業で触った程度で、まだ自信がありません。",
          future: "たくさんの人に遊ばれるゲームのサーバーや運用にも興味があり、裏側の仕組みも学びたいです。",
          skills: [ [ "C#", 1.5, "v2" ], [ "Unity", 1.5, "v2" ], [ "C++", 0.5, "v1" ], [ "Go", 0.5, "v1" ] ]
        }
      ]
    },
    undecided: {
      jobs: %w[4-4 1-1], industries: [ "教育", "人材・HR" ],
      profiles: [
        {
          strength: "プログラミングは大学1年から始め、授業の課題を中心に Python と JavaScript を学んでいます。" \
                    "わからないことを調べてまとめ、友人に説明するのが好きです。",
          weakness: "まだ大きなものを作った経験がなく、どの分野に進むか決めきれていません。",
          future: "インターンで実際の仕事を見て、自分に合う分野を見つけたいです。人の話を聞いて、何を作るかを考える仕事にも興味があります。",
          skills: [ [ "Python", 0.5, "v2" ], [ "JavaScript", 0.5, "v1" ], [ "Processing", 0.5, "v1" ] ]
        },
        {
          strength: "文学部ですが、独学で HTML と JavaScript を学び、サークルのホームページを作りました。" \
                    "文章を書くことが得意で、わかりやすい説明を心がけています。",
          weakness: "数学やアルゴリズムの知識は、まだ足りないと感じています。",
          future: "技術と人をつなぐ役割に興味があり、企画やディレクションの仕事を経験してみたいです。",
          skills: [ [ "JavaScript", 0.5, "v1" ], [ "Figma", 0.5, "v1" ] ]
        }
      ]
    }
  }.freeze

  # ── 学生（20人）──
  # type・profile：上のタイプと、その何番目の文章か（0 か 1）。minimal: true の学生は、必須（氏名・活動状況）だけ入れる。
  # work は [週の日数, 1日の時間, 継続期間, 開始時期（今月から何か月後。nil は未入力）]。
  # remote は [フルリモート, 一部リモート, 出社] の可否。personality は [進め方, 新しさ, 周囲との関わり, 決め手, 職場の雰囲気]。
  # active：最終活動日が何日前か（30日より前の学生は、学生検索に出ない）
  STUDENTS = [
    { name: "佐藤 陽斗", type: :frontend, profile: 0, university: "東京大学", faculty: "工学部", department: "情報工学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "東京都", activity_status: "job_hunting",
      work: [ 3, 4, 6, 0 ], remote: [ true, true, true ], commutable: [ "東京都", "神奈川県" ], personality: [ -1, -1, 1, 1, 0 ], active: 1 },
    { name: "鈴木 美咲", type: :backend, profile: 0, university: "早稲田大学", faculty: "情報学部", department: "情報システム学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "東京都", activity_status: "job_hunting",
      work: [ 3, 5, 6, 0 ], remote: [ true, true, true ], commutable: [ "東京都" ], personality: [ -2, -1, 0, -1, -1 ], active: 2 },
    { name: "高橋 蓮", type: :frontend, profile: 1, university: "慶應義塾大学", faculty: "理学部", department: "数学科",
      grade: "undergrad_2", graduation_year: 2029, prefecture: "神奈川県", activity_status: "skill_up",
      work: [ 2, 4, 3, 1 ], remote: [ true, true, false ], commutable: [ "東京都", "神奈川県" ], personality: [ -2, -2, -1, 1, 0 ], active: 0 },
    { name: "田中 結衣", type: :backend, profile: 1, university: "九州大学", faculty: "工学部", department: "電気電子工学科",
      grade: "master_1", graduation_year: 2028, prefecture: "福岡県", activity_status: "skill_up",
      work: [ 3, 4, 6, 0 ], remote: [ true, true, true ], commutable: [ "福岡県" ], personality: [ -1, 0, -1, -2, 1 ], active: 3 },
    { name: "伊藤 湊", type: :backend, profile: 1, university: "大阪大学", faculty: "工学部", department: "情報工学科",
      grade: "undergrad_4", graduation_year: 2027, prefecture: "大阪府", activity_status: "job_hunting",
      work: [ 4, 6, 9, 0 ], remote: [ true, false, false ], commutable: [], personality: [ 0, 1, -1, -2, 2 ], active: 1 },
    { name: "渡辺 葵", type: :data_ai, profile: 0, university: "京都大学", faculty: "経済学部", department: "経済学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "京都府", activity_status: "skill_up",
      work: [ 2, 4, 6, 1 ], remote: [ true, true, true ], commutable: [ "京都府", "大阪府" ], personality: [ -1, -1, 1, -2, 0 ], active: 4 },
    { name: "山本 大和", type: :data_ai, profile: 1, university: "東北大学", faculty: "情報学部", department: "情報科学科",
      grade: "master_1", graduation_year: 2028, prefecture: "宮城県", activity_status: "job_hunting",
      work: [ 2, 5, 12, 0 ], remote: [ true, false, false ], commutable: [], personality: [ 1, -1, -1, -2, 2 ], active: 2 },
    { name: "中村 さくら", type: :backend, profile: 0, university: "大阪公立大学", faculty: "工学部", department: "情報工学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "大阪府", activity_status: "job_hunting",
      work: [ 3, 5, 9, 0 ], remote: [ true, true, true ], commutable: [ "大阪府", "兵庫県" ], personality: [ 2, 1, 1, -1, 1 ], active: 5 },
    { name: "小林 悠真", type: :game, profile: 0, university: "立命館大学", faculty: "情報学部", department: "情報メディア学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "京都府", activity_status: "skill_up",
      work: [ 3, 5, 6, 1 ], remote: [ true, true, true ], commutable: [ "京都府", "滋賀県" ], personality: [ -2, -1, 1, 1, -2 ], active: 0 },
    { name: "加藤 凛", type: :game, profile: 1, university: "同志社大学", faculty: "理学部", department: "物理学科",
      grade: "undergrad_2", graduation_year: 2029, prefecture: "京都府", activity_status: "skill_up",
      work: [ 2, 4, 6, 2 ], remote: [ true, true, false ], commutable: [ "京都府" ], personality: [ -1, -2, 1, 0, -1 ], active: 6 },
    { name: "吉田 颯太", type: :infra, profile: 0, university: "東京科学大学", faculty: "工学部", department: "情報工学科",
      grade: "undergrad_4", graduation_year: 2027, prefecture: "東京都", activity_status: "job_hunting",
      work: [ 2, 6, 6, 0 ], remote: [ true, true, true ], commutable: [ "東京都" ], personality: [ 1, -1, -1, -1, 2 ], active: 3 },
    { name: "山田 陽菜", type: :undecided, profile: 1, university: "明治大学", faculty: "文学部", department: "日本文学科",
      grade: "undergrad_2", graduation_year: 2029, prefecture: "東京都", activity_status: "skill_up",
      work: [ 2, 4, 6, 1 ], remote: [ true, true, true ], commutable: [ "東京都", "埼玉県" ], personality: [ 0, 1, 2, 1, -1 ], active: 8 },
    { name: "佐々木 樹", type: :infra, profile: 1, university: "筑波大学", faculty: "情報学部", department: "情報システム学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "茨城県", activity_status: "skill_up",
      work: [ 2, 4, 6, 1 ], remote: [ true, true, false ], commutable: [ "茨城県", "東京都" ], personality: [ 2, 1, 1, -1, 1 ], active: 10 },
    { name: "山口 芽依", type: :data_ai, profile: 0, university: "名古屋大学", faculty: "経済学部", department: "経営学科",
      grade: "undergrad_3", graduation_year: 2028, prefecture: "愛知県", activity_status: "job_hunting",
      work: [ 3, 6, 6, 0 ], remote: [ false, true, true ], commutable: [ "愛知県" ], personality: [ 2, 2, 2, -1, 0 ], active: 12 },
    { name: "松本 陸", type: :game, profile: 0, university: "北海道大学", faculty: "工学部", department: "機械工学科",
      grade: "undergrad_4", graduation_year: 2027, prefecture: "北海道", activity_status: "job_hunting",
      work: [ 2, 3, 3, 0 ], remote: [ true, false, false ], commutable: [], personality: [ -1, 0, 1, -2, 0 ], active: 5 },
    { name: "井上 杏", type: :data_ai, profile: 1, university: "東京理科大学", faculty: "理学部", department: "化学科",
      grade: "master_2", graduation_year: 2027, prefecture: "千葉県", activity_status: "skill_up",
      work: [ 2, 4, 3, 0 ], remote: [ true, true, true ], commutable: [ "東京都", "千葉県" ], personality: [ 0, 0, 1, -2, 1 ], active: 7 },
    # 働き方の好みを触っていない学生（5軸がすべて真ん中）
    { name: "木村 蒼", type: :undecided, profile: 0, university: "神戸大学", faculty: "工学部", department: "建築学科",
      grade: "undergrad_1", graduation_year: 2030, prefecture: "兵庫県", activity_status: "not_looking",
      work: [ 1, 2, 3, nil ], remote: [ true, false, false ], commutable: [], personality: [ 0, 0, 0, 0, 0 ], active: 45 },
    # 必須（氏名・活動状況）だけの学生
    { name: "林 心春", minimal: true, activity_status: "skill_up", active: 20 },
    { name: "清水 海斗", minimal: true, activity_status: "job_hunting", active: 40 },
    { name: "斎藤 莉子", minimal: true, activity_status: "not_looking", active: 60 }
  ].freeze

  # ── やりとり ──
  # student は STUDENTS の何番目か（1から数える。メールアドレスの番号と同じ）。reasons は応募理由・マッチ理由の英語の名前

  # 応募（matched: true なら、そのあと企業がマッチする）
  APPLICATIONS = [
    { student: 1, posting: :edu_frontend, reasons: %w[business job_middle_category technologies] },
    { student: 2, posting: :logi_fullstack, reasons: %w[job_middle_category technologies work_conditions] },
    { student: 6, posting: :edu_data, reasons: %w[industry internship_details culture] },
    { student: 9, posting: :game_client, reasons: %w[industry job_middle_category growth] },
    { student: 12, posting: :si_pdm, reasons: %w[work_process internship_details growth] },
    { student: 14, posting: :med_ml, reasons: %w[business technologies] },
    { student: 3, posting: :edu_frontend, reasons: %w[business culture growth], matched: true },
    { student: 4, posting: :logi_api, reasons: %w[job_middle_category work_process technologies], matched: true },
    { student: 8, posting: :med_backend, reasons: %w[industry hourly_wage work_conditions], matched: true },
    { student: 10, posting: :game_server, reasons: %w[job_major_category technologies culture], matched: true }
  ].freeze

  # スカウト（reasons があれば、そのあと学生がマッチする）
  SCOUTS = [
    { posting: :edu_llm, student: 7 },
    { posting: :logi_infra, student: 11 },
    { posting: :med_qa, student: 13 },
    { posting: :si_system, student: 5 },
    { posting: :game_data, student: 15 },
    { posting: :med_ml, student: 16, reasons: %w[business internship_details technologies] },
    { posting: :logi_api, student: 2, reasons: %w[business_type work_conditions culture] },
    { posting: :si_security, student: 13, reasons: %w[job_middle_category growth] }
  ].freeze

  # スカウト文。%{last_name} は学生の姓、%{company} は会社名、%{title} は募集名、%{skill} は学生のプログラミング歴の最初の技術
  SCOUT_BODY = "%{last_name}さん、はじめまして。%{company}の採用担当です。\n" \
               "プロフィールを拝見し、%{skill}の経験に惹かれてご連絡しました。" \
               "「%{title}」で、ぜひ力を貸していただきたいと考えています。\n" \
               "まずはオンラインで30分ほど、仕事の中身やチームの雰囲気をお話しできればうれしいです。" \
               "ご興味があれば、募集詳細から「マッチする」を押していただけますと幸いです。"

  # マッチしたあとのメッセージ。from は company（企業）か student（学生）。
  # マッチした組ごとに、先頭から2〜4通を使う
  MESSAGES = [
    { from: :company, body: "マッチありがとうございます。%{company}の採用担当です。\n" \
                            "一度オンラインで30分ほどお話しできればと思います。下のフォームから、ご都合のよい日時をお選びください。\n" \
                            "https://example.com/schedule" },
    { from: :student, body: "ご連絡ありがとうございます。フォームから、来週水曜日の16時で登録しました。当日はよろしくお願いいたします。" },
    { from: :company, body: "ご登録ありがとうございます。当日は、仕事の内容と、最初の1か月の進め方をご説明します。事前に気になることがあれば、ここで聞いてください。" },
    { from: :student, body: "ありがとうございます。週に何時間くらいから始める方が多いか、当日伺えればうれしいです。" }
  ].freeze
end
