require "rails_helper"

# 募集のデータベースの CHECK のテスト。
# 「掲載に必要」（状態が掲載中なら、インターンですること・時給は空欄不可）を、モデルの検証をすり抜けてもデータベースが守ることを確かめる。
# 詳しくは design/designs/データベース.md の 8-5 job_postings、権限_バリデーション.md の 17-3-3
RSpec.describe JobPosting, type: :model do
  describe "データベースの CHECK（掲載に必要）" do
    # update_columns は、モデルの検証も保存前の処理も飛ばして、SQL を直接送る（Django の QuerySet.update() に近い）
    it "掲載中の募集のインターンですることを、検証を通さずに空欄にしようとすると、データベースが拒否する" do
      job_posting = create(:job_posting, :published)

      expect { job_posting.update_columns(internship_details: nil) }.to raise_error(ActiveRecord::CheckViolation)
    end

    it "非公開の募集なら、同じ書き込みができる" do
      job_posting = create(:job_posting)

      expect { job_posting.update_columns(internship_details: nil) }.not_to raise_error
    end
  end
end
