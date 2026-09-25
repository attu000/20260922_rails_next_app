# company_industries（企業の業界。企業×業界の中間テーブル）。design/designs/データベース.md の 8-5。
# 会社の紹介として表示するだけで、検索・おすすめには使わない（使うのは募集の業界。その他決め事.md の 5-8）
class CreateCompanyIndustries < ActiveRecord::Migration[8.1]
  def change
    create_table :company_industries do |t|
      t.references :company_profile, null: false, foreign_key: true
      t.references :industry, null: false, foreign_key: true

      t.timestamps
    end

    # UNIQUE(両方)：同じ会社に同じ業界を2回付けない
    add_index :company_industries, %i[company_profile_id industry_id], unique: true
  end
end
