# ㉓ GET /api/company/students/:id の形（design/designs/API設計.md の 16-3-6）。
# has_message_thread は順6、comparison は順10、last_active_range は【仕上げ】の順16、self_analyses は順19 で足した

# 学生のプロフィール。マイページと同じ項目（マッチ前でもすべて見せる）
json.student do
  json.partial! "api/shared/student_profile", student: @student
  # 最終活動の目安。学生詳細だけ、30日より前（over_30_days）も出る。一度もログインしていなければ null（PR335）
  json.last_active_range @student.last_active_range
end
# この学生とのスレッドがあるか。募集ごとではなく学生ごとの値なので、job_postings の外に置く。
# true なら、どの募集タブでも「この学生とのメッセージ」のボタンを出す（ボタンは順7。PR213）
json.has_message_thread @has_message_thread
# この学生の自己分析（修了したプチ職業体験）。修了した日の新しい順。なければ空の配列（順19。PR372）。
# 学生ごとの値なので、job_postings の外に置く。ポップアップを開くたびに取りに行かず、ここに全部入れる（PR386）。
# 画面は講座の中身を持たないので、講座名とハードルの名前もここに入れる
json.self_analyses @self_analyses do |self_analysis|
  json.job_trial do
    json.extract! self_analysis.job_trial, :id, :title
  end
  json.strength_hurdle do
    json.extract! self_analysis.strength_hurdle, :id, :name
  end
  json.strength_reason self_analysis.strength_reason
  json.growth_hurdle do
    json.extract! self_analysis.growth_hurdle, :id, :name
  end
  json.extract! self_analysis, :growth_reason, :growth_detail, :next_step
  # 1-1 と 2-1 が同じハードルか（「得意を伸ばしたい」と添えるか。判定は Rails。PR360）
  json.same_hurdle self_analysis.same_hurdle?
  json.extract! self_analysis, :created_at, :updated_at
end
# 自社の全募集。1件ずつ、その学生とのやりとりと押せるボタン（形D）に、比較を加える。
# 比較はこの窓口だけに入れる（スカウト・マッチの返事の形D には入れない。スカウトやマッチをしても比較は変わらないため）
json.job_postings @job_postings do |job_posting|
  json.partial! "api/company/students/job_posting",
                job_posting: job_posting, candidacy: @candidacies_by_job_posting_id[job_posting.id]
  json.comparison do
    json.partial! "api/company/students/comparison", student: @student, job_posting: job_posting
  end
end
