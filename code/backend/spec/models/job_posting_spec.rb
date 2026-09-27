require "rails_helper"

# 募集のモデルのテスト。
# - データベースの CHECK：「掲載に必要」とカルチャーの範囲を、モデルの検証をすり抜けてもデータベースが守ること
# - 募集の保存（save_posting）のうち、工程・業界・事業形態・カルチャー（順9）の部分。
#   窓口がこれらを受け取るのは 9-4 からなので、ここではモデルを直接呼んで確かめる
# 詳しくは design/designs/データベース.md の 8-5 job_postings、権限_バリデーション.md の 17-3-3・17-3-4
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

  describe "データベースの CHECK（カルチャーは −2〜2）" do
    it "範囲の外の値を、検証を通さずに書き込もうとすると、データベースが拒否する" do
      job_posting = create(:job_posting)

      expect { job_posting.update_columns(culture_pace: 3) }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "#save_posting（工程・業界・事業形態・カルチャー）" do
    let(:job_posting) { create(:job_posting) }
    let(:processes) { create_list(:work_process, 3) }
    let(:industry) { create(:industry) }
    let(:business_type) { create(:business_type) }

    it "工程・業界・事業形態・カルチャーを保存でき、読み出すと同じ値が返る" do
      result = job_posting.save_posting(
        main_work_process_ids: [ processes[0].id ],
        involved_work_process_ids: [ processes[1].id, processes[2].id ],
        industry_ids: [ industry.id ],
        business_type_ids: [ business_type.id ],
        culture_pace: -2,
        culture_atmosphere: 1
      )

      expect(result).to be(true)
      job_posting.reload
      expect(job_posting.main_work_process_ids).to eq([ processes[0].id ])
      expect(job_posting.involved_work_process_ids).to contain_exactly(processes[1].id, processes[2].id)
      expect(job_posting.industry_ids).to eq([ industry.id ])
      expect(job_posting.business_type_ids).to eq([ business_type.id ])
      expect(job_posting.culture_pace).to eq(-2)
      expect(job_posting.culture_atmosphere).to eq(1)
    end

    it "メインと関われるに同じ工程があると保存されず、関われる工程にエラーが付く。何も書き込まれない" do
      result = job_posting.save_posting(
        title: "書き換えたタイトル",
        main_work_process_ids: [ processes[0].id ],
        involved_work_process_ids: [ processes[0].id ]
      )

      expect(result).to be(false)
      expect(job_posting.errors.full_messages_for(:involved_work_process_ids))
        .to eq([ "関われる工程に、メインで担当する工程と同じものが含まれています" ])
      job_posting.reload
      expect(job_posting.title).not_to eq("書き換えたタイトル")
      expect(job_posting.job_posting_work_processes).to be_empty
    end

    it "マスタにない工程の番号は、選べない値のエラーになる" do
      result = job_posting.save_posting(main_work_process_ids: [ 0 ])

      expect(result).to be(false)
      expect(job_posting.errors.full_messages_for(:main_work_process_ids))
        .to eq([ "メインで担当する工程に選べない値が含まれています" ])
    end

    it "カルチャーが範囲の外（3）だと保存されない" do
      result = job_posting.save_posting(culture_pace: 3)

      expect(result).to be(false)
      expect(job_posting.errors.full_messages_for(:culture_pace)).to eq([ "カルチャー（進め方）は2以下の値にしてください" ])
      expect(job_posting.reload.culture_pace).to eq(0)
    end

    it "工程を送らなかったときは、今の工程がそのまま残る" do
      job_posting.save_posting(main_work_process_ids: [ processes[0].id ], involved_work_process_ids: [ processes[1].id ])

      job_posting.save_posting(title: "タイトルだけ直す")

      job_posting.reload
      expect(job_posting.main_work_process_ids).to eq([ processes[0].id ])
      expect(job_posting.involved_work_process_ids).to eq([ processes[1].id ])
    end
  end
end
