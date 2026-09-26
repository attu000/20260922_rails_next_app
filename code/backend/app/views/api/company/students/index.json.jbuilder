# ㉒ GET /api/company/students の形（design/designs/API設計.md の 16-3 ㉒、16-1-11）。
# 行は形C に、次の3つを足したもの
#   - matched：指定した条件を全部満たすか（Rails が判定する）
#   - candidacy：募集を選んだときの、その募集とのやりとり。なければ null（募集を選ばないときは常に null）
#   - candidacy_count：自社の募集とのやりとりの件数（募集を選ばないときの「やりとりあり」のタグ用）
# 並び順は、合致の群がすべて先、そのあとに合致外の群（コントローラーと app/services/student_search.rb で並べ済み）。
# もうスカウトした・見送った・マッチした学生は、検索の本体が除いてある（PR220）

json.items @students do |student|
  json.partial! "api/company/students/row", student: student
  json.matched @matched_ids.include?(student.id)

  # 行のタグ（PR219）。除外のあとなので、残っているのは未対応応募だけ
  candidacy = @candidacies_by_student_id[student.id]
  if candidacy
    json.candidacy do
      json.extract! candidacy, :id, :origin, :status
      # 企業から見たタグ（Candidacy#tag）。json.tag と書くと画面の部品を作る命令と取り違えられるので、set! で名前を明示する
      json.set! :tag, candidacy.tag
    end
  else
    json.candidacy nil
  end
  json.candidacy_count @candidacy_counts.fetch(student.id, 0)
end
json.partial! "api/shared/pagination", pagy: @pagy, matched_count: @matched_count
