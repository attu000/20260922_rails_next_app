# 企業から見た、募集ごとのやりとりの状態（形D。design/designs/API設計.md の 16-3-2）。
# ㉓ 学生詳細の job_postings の要素と、㉔ スカウト・㉖ マッチ（順11 で ㉗〜㉚）の返事で使い回す。
# 使い方：json.partial! "api/company/students/job_posting", job_posting: 募集, candidacy: その学生とのやりとり（なければ nil）

json.extract! job_posting, :id, :title, :status
if candidacy
  json.candidacy do
    json.extract! candidacy, :id, :origin, :status
    # 企業から見たタグ（Candidacy#tag）。json.tag と書くと画面の部品を作る命令と取り違えられるので、set! で名前を明示する
    json.set! :tag, candidacy.tag
    # 応募理由・マッチ理由の名前の一覧（順10）。学生詳細の上に、12個の一覧で見せる。
    # スカウトしただけでまだマッチしていなければ、空の配列（マッチ理由は、学生がマッチしたときに選ぶ）
    json.reasons candidacy.reasons
    json.matched_at candidacy.matched_at
  end
else
  json.candidacy nil
end
# 今押せるボタン。判定は Rails の1か所（Candidacy.available_actions_for）で行い、画面はここにあるボタンだけを出す（16-1-9）
json.available_actions Candidacy.available_actions_for(job_posting, candidacy)
