# company_business_types（企業の事業形態。企業×事業形態の中間テーブル）。design/designs/データベース.md の 8-5。
# 会社の紹介として表示するだけで、検索・おすすめには使わない（使うのは募集の事業形態。その他決め事.md の 5-8）
class CreateCompanyBusinessTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :company_business_types do |t|
      t.references :company_profile, null: false, foreign_key: true
      t.references :business_type, null: false, foreign_key: true

      t.timestamps
    end

    # UNIQUE(両方)：同じ会社に同じ事業形態を2回付けない
    add_index :company_business_types, %i[company_profile_id business_type_id], unique: true
  end
end
