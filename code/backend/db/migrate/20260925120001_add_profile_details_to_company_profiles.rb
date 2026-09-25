# company_profiles（企業プロフィール）の残りの列。design/designs/データベース.md の 8-5
# 3つとも任意。企業プロフィールで必須は会社名だけで、新規登録でも企業プロフィール編集でも同じ（その他決め事.md の 5-9）
class AddProfileDetailsToCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    # 事業内容
    add_column :company_profiles, :business_description, :text
    # どんな会社か
    add_column :company_profiles, :about, :text
    # 人数。size_1_9：0 〜 size_1000_plus：5（番号は CompanyProfile モデルの enum で明示する）
    add_column :company_profiles, :employee_size, :integer
  end
end
