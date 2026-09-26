# ㉛ POST /api/student/candidacies の返事（design/designs/API設計.md の 16-3-6）。形E を返す
json.partial! "api/student/candidacies/my_status", candidacy: @candidacy
