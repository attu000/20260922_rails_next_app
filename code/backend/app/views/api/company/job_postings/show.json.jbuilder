# ⑫ GET /api/company/job_postings/:id の形。⑬ 新規作成・⑭ 保存の返事も同じ（design/designs/API設計.md の 16-3 ⑫）。
# 作った列を、学生に見せない項目も含めてそのまま返す（会社の番号は返さない）。
# 空欄は null のまま返す。どんな会社か・事業内容が null なら、画面側は企業プロフィールの値を薄く表示する。
# 目的・求める人材は【仕上げ】で足す

json.extract! @job_posting,
              :id, :status, :published_at,
              :title, :about, :business_description, :internship_details, :growth,
              :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months, :start_month,
              :work_style, :work_style_note, :prefecture_id, :work_location_note, :weekend_ok, :work_note,
              :hourly_wage, :requirements, :preferred_requirements, :technology_note,
              # カルチャーの5軸。−2〜2 の数値
              :culture_pace, :culture_novelty, :culture_collaboration, :culture_decision, :culture_atmosphere,
              # 職種と工程は「主な／関連する」「メインで担当する／関われる」で配列を分けて返す（フォームの入力欄とそのまま対応させるため）
              :main_job_middle_category_ids, :related_job_middle_category_ids,
              :main_work_process_ids, :involved_work_process_ids,
              :technology_ids,
              # この募集の業界・事業形態。企業プロフィールの値とは別に持つ（その他決め事.md の 5-8）
              :industry_ids, :business_type_ids,
              # この募集に近いプチ職業体験の講座（講座の表示順。順19。PR374）
              :job_trial_ids,
              :updated_at
