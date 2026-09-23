# company_profiles（企業プロフィール）。design/designs/データベース.md の 8-5
# Phase 5 では user_id と会社名だけを作る。残りの列は、企業プロフィールの機能を作るときに Phase 6 で足す（未決内容.md の 11-2）
class CreateCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :company_profiles do |t|
      # UNIQUE：1社1アカウント
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      # 会社名
      t.string :name, null: false

      t.timestamps
    end
  end
end
