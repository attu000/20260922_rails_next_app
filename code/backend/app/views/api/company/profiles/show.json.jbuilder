# ⑧ GET /api/company/profile と ⑨ PATCH /api/company/profile の形（design/designs/API設計.md の 16-3 ⑧）

json.name @company.name
json.industry_ids @company.industry_ids
json.business_type_ids @company.business_type_ids
# 番号ではなく名前（"size_10_49"）で返す。空欄なら null（16-1-8）
json.employee_size @company.employee_size
json.business_description @company.business_description
json.about @company.about
json.partial! "api/shared/icon_url", record: @company
