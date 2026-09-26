# 学生の一覧の1行（design/designs/API設計.md の 16-3 ㉞・㉟）。
# 形B に、やりとりの番号（candidacy_id）と自分の状態（my_status）を足したもの。㉞ 募集管理と ㉟ スカウト管理で使い回す。
# 使い方：json.partial! "api/student/candidacies/row", candidacy: やりとり
#
# my_status は、募集管理なら applied（応募済み）か matched（マッチ済み）、スカウト管理なら常に scouted（スカウトあり）。
# 企業側の見送り・合格・不合格は学生に見せない（Candidacy#my_status）

json.partial! "api/student/job_postings/job_posting", job_posting: candidacy.job_posting
json.candidacy_id candidacy.id
json.my_status candidacy.my_status
