# ⑲ GET /api/student/job_postings/:id の形（design/designs/API設計.md の 16-3 ⑲）。
# 返さない項目：状態（代わりに is_open）と、目的・採用につながる可能性・求める人材（学生に見せない項目）。
# 次のものは、それを作る順で足す（PR189）
#   - 自分の状態（my_status、my_candidacy_id）：順5（済み）
#   - その企業とのスレッドがあるか（has_message_thread）：順6（済み）
#   - 業界・事業形態・工程、カルチャーの5つ：順9（済み）
#   - 自分の働き方の好みの5つ（my_personality_）：順10（済み）。
#     一致・ずれの判定（culture_comparison）はやめ、カルチャーグラフに自分の値を黒丸で重ねるだけにした（PR258）
#   - この募集に近いプチ職業体験（job_trials）：順19（済み）

company = @job_posting.company_profile

json.extract! @job_posting, :id, :title
# 掲載中なら true。false なら、画面は「募集終了」と出す（やりとりがあれば、非公開・終了の募集も開ける）
json.is_open @job_posting.published?
# 自分の状態（形E）
json.partial! "api/student/candidacies/my_status", candidacy: @candidacy
# その企業とのスレッドがあるか。true なら「この企業とのメッセージ」のボタンを出す（ボタンは順7。PR213）
json.has_message_thread @has_message_thread
json.company do
  json.id company.id
  json.name company.name
  json.partial! "api/shared/icon_url", record: company
end
# どんな会社か・事業内容は、募集が空欄なら企業プロフィールの値を入れて返す（学生の画面では区別が要らないため）
json.about @job_posting.about || company.about.presence
json.business_description @job_posting.business_description || company.business_description.presence
json.extract! @job_posting,
              :internship_details, :growth,
              # 稼働条件
              :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months, :start_month,
              :work_style, :work_style_note, :prefecture_id, :work_location_note, :weekend_ok, :work_note,
              :hourly_wage, :requirements, :preferred_requirements, :technology_note,
              # 職種と工程は「主な／関連する」「メインで担当する／関われる」で配列を分けて返す（⑫と同じ名前）
              :main_job_middle_category_ids, :related_job_middle_category_ids,
              :main_work_process_ids, :involved_work_process_ids,
              :technology_ids,
              # その募集の業界・事業形態。どんな会社か・事業内容と違い、空欄でも企業プロフィールの値で補わない（その他決め事.md の 5-8）
              :industry_ids, :business_type_ids,
              # カルチャーの5軸（カルチャーグラフ）。−2〜2 の数値
              :culture_pace, :culture_novelty, :culture_collaboration, :culture_decision, :culture_atmosphere,
              :published_at
# 自分の働き方の好みの5軸。−2〜2 の数値。カルチャーグラフに黒丸で重ねる（PR258）。
# 名前に my_ を付けて、募集のカルチャー（culture_）と区別する（my_status と同じ付け方）
CultureAxes::AXES.each do |axis|
  json.set! "my_personality_#{axis}", @student.public_send("personality_#{axis}")
end
# 企業が選んだ、この募集に近いプチ職業体験の講座（講座の表示順。順19。PR374）。なければ空の配列。
# completed は、自分がその講座の自己分析を送っているか（修了済み。判定は Rails）
json.job_trials @job_trials do |job_trial|
  json.extract! job_trial, :id, :title
  json.completed @completed_job_trial_ids.include?(job_trial.id)
end
