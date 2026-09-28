# 推薦（おすすめ）のパラメータを、ここ1か所にまとめる（design/designs/処理設計_類似度.md の 7-4、技術構成.md の 9-1）。
# データベースではなくコードに置く。値はどれも仮で、パラメータの調整（Recall@K・nDCG による評価）のときに見直す（未決内容.md の 10-1）。
# YAML の設定ファイルにしないのは、環境ごとに変える値ではなく、計算のコードからそのまま使うため（PR297）。
# Django でいえば、recommendation/parameters.py に定数を並べるのにあたる。
# 使う計算を作るときに、その計算のパラメータを足していく（使わない値を先に置かない）
module Recommendation
  module Parameters
    # 内容の近さ（Content）の、項目ごとの重み（7-2 の表）。組み合わせごとに合計1。
    #   job_category：職種、work_process：工程（募集どうしのみ）、technology：技術、industry：業界、culture：カルチャー・性格
    # 業界 = 職種 = 技術 > カルチャー（PR300）。カルチャーは未入力がなく（初期値が中央）、ほぼ全員に同じように乗る
    # 底上げになるので軽くし、入力した項目の一致で差が付くようにする。カルチャーの一致は、比較の画面で2つの点として見せる
    CONTENT_WEIGHTS = {
      posting_student: { job_category: 0.30, technology: 0.30, industry: 0.30, culture: 0.10 }.freeze,
      student_student: { job_category: 0.30, technology: 0.30, industry: 0.30, culture: 0.10 }.freeze,
      posting_posting: { job_category: 0.25, work_process: 0.15, technology: 0.25, industry: 0.25, culture: 0.10 }.freeze
    }.freeze

    # 職種の中分類が1つも重ならないときに、大分類のジャカード係数にかける数（7-2 の表）
    JOB_MAJOR_FALLBACK = 0.5

    # 以下は順13 の 13-2（行動の近さと、募集どうし・学生どうしの f）で足したもの（7-2・7-4）

    # λ：行動データを信頼し始める件数。データ量に応じた信頼度 c(n) = n ÷ (n + λ)。λ > 0
    CONFIDENCE_LAMBDA = 10

    # 行動の近さ（CF）を重視する上限。募集どうしは w_max^P、学生どうしは w_max^S（0〜1）
    BEHAVIOR_WEIGHT_MAX = { posting: 0.6, student: 0.7 }.freeze

    # β：応募理由が1つも一致しなくても与える基礎点。g = β + (1 − β) × 理由のジャカード係数（0〜1）
    REASON_BASE = 0.5

    # 計算に使う興味の数の上限（PR287）。興味を示した日時の新しい順に、募集ごとに L_P 人、学生ごとに L_S 件まで。
    # 件数（interest_count）と self_weight は、上限をかけずに全員分で数える
    INTERESTS_PER_POSTING = 200
    INTERESTS_PER_STUDENT = 20

    # 以下は順13 の 13-3a（募集×学生の f）で足したもの（7-2・7-4）

    # γ：I と U それぞれの重みの上限。w_I = γ × c(|A(S)|)、w_U = γ × c(|B(P)|)、w_C = 1 − w_I − w_U（0〜0.5）
    NEIGHBOR_WEIGHT_MAX = 0.3

    # p：I と U のべき平均の指数（p ≥ 1）。1 なら普通の平均。大きくするほど、近い相手を重く見る
    POWER_MEAN_EXPONENT = 1

    # 以下は順13 の 13-3b（1次検索と、群ごとの上位の選び方）で足したもの（7-4・7-5）

    # R：おすすめ順で、群ごとに f(P, S) で並べ直す件数（リランキング）。101件目以降は新着順・最終活動の順（PR280）
    RERANK_SIZE = 100

    # N_C：学生検索の1次検索で、内容の経路から群ごとに取る候補の人数（PR282）
    CONTENT_ROUTE_SIZE = 1000

    # K_B：学生検索の1次検索で、行動の経路に使う募集の数（P と行動が近い上位の募集。PR282）
    BEHAVIOR_ROUTE_POSTINGS = 20

    # 学生検索の1次検索で、行動の経路から取る学生の数の上限（K_B 件 × L_P 人）
    BEHAVIOR_ROUTE_MAX_STUDENTS = 4000

    # 以下は順14（似たもののポップアップ）で足したもの（7-3・7-4）

    # 似たもののポップアップ（似た学生・似た募集）に出す件数。順15 の通知の上位5社も同じ数を使う（PR318）
    SIMILAR_LIMIT = 5
  end
end
