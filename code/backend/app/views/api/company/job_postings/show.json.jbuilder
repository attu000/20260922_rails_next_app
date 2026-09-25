# ⑫ GET /api/company/job_postings/:id の形。⑬ 新規作成・⑭ 保存の返事も同じ（design/designs/API設計.md の 16-3 ⑫）。
# 順2 で作った列を、学生に見せない項目も含めてそのまま返す（会社の番号は返さない）。
# 空欄は null のまま返す。どんな会社か・事業内容が null なら、画面側は企業プロフィールの値を薄く表示する。
# 業界・事業形態・工程・カルチャーは順9、目的・求める人材は【仕上げ】で足す

json.extract! @job_posting,
              :id, :status, :published_at,
              :title, :about, :business_description, :internship_details, :growth,
              :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months, :start_month,
              :work_style, :work_style_note, :prefecture_id, :work_location_note, :weekend_ok, :work_note,
              :hourly_wage, :requirements, :preferred_requirements, :technology_note,
              # 職種は「主な／関連する」で配列を分けて返す（フォームの入力欄とそのまま対応させるため）
              :main_job_middle_category_ids, :related_job_middle_category_ids,
              :technology_ids,
              :updated_at
