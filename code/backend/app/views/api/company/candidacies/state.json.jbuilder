# ㉖〜㉚ 企業のやりとりの操作（マッチ・見送り・見送りの取り消し・合格・不合格）の返事（design/designs/API設計.md の 16-3-6）。
# 操作したあとの、その募集の状態（形D）を返す。5つとも同じ形なので、テンプレートを1つにまとめている（PR270）
json.partial! "api/company/students/job_posting", job_posting: @candidacy.job_posting, candidacy: @candidacy
