# ㉔ POST /api/company/scouts の返事（design/designs/API設計.md の 16-3-6）。
# スカウトしたあとの、その募集の状態（形D）を返す
json.partial! "api/company/students/job_posting", job_posting: @candidacy.job_posting, candidacy: @candidacy
