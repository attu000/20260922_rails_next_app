# ⑦ GET /api/options の形（design/designs/API設計.md の 16-3 ⑦）。
# 順1 で使う選択肢とマスタだけを返す。ほかの項目（職種、大学、稼働条件の数値など）は、使う順で足す（未決内容.md の 11-2）

json.enums do
  # 人数。値はモデルの enum の名前、表示名は config/locales/ja.yml から取る
  json.employee_size CompanyProfile.employee_sizes.keys do |value|
    json.value value
    json.label t("enums.company_profile.employee_size.#{value}")
  end
end

json.masters do
  json.industries @industries, :id, :name
  json.business_types @business_types, :id, :name
end
