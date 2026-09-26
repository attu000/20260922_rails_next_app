require "rails_helper"

# やりとりのテスト。
# タグと学生から見た状態の計算（API設計.md の 16-3 ㉑・形D・形E、データベース.md の 8-7）と、
# 番号・データベースの制約（データベース.md の 8-5 candidacies・candidacy_reasons）を確かめる
RSpec.describe Candidacy, type: :model do
  # 発生元 × 状態 → [企業から見たタグ, 学生から見た状態]
  expectations = {
    %i[application unmatched] => %w[pending_application applied],
    %i[application matched] => %w[matched matched],
    %i[application declined] => %w[declined applied],
    %i[application passed] => %w[passed matched],
    %i[application failed] => %w[failed matched],
    %i[scout unmatched] => %w[scouted scouted],
    %i[scout matched] => %w[matched matched],
    %i[scout declined] => %w[declined scouted],
    %i[scout passed] => %w[passed matched],
    %i[scout failed] => %w[failed matched]
  }

  # 計算は列の値だけで決まるので、データベースに保存せずに確かめる
  describe "#tag（企業から見たタグ）" do
    expectations.each do |(origin, status), (tag, _my_status)|
      it "発生元が #{origin}、状態が #{status} なら #{tag}" do
        expect(described_class.new(origin:, status:).tag).to eq(tag)
      end
    end
  end

  describe "#my_status（学生から見た状態）" do
    expectations.each do |(origin, status), (_tag, my_status)|
      it "発生元が #{origin}、状態が #{status} なら #{my_status}" do
        expect(described_class.new(origin:, status:).my_status).to eq(my_status)
      end
    end
  end

  # 番号は保存されている値そのものなので、並べ替えなどでずれると、既存のデータの意味が変わってしまう（技術構成.md の 9-1）
  describe "enum の番号" do
    it "発生元と状態の番号が、設計書の表と一致する" do
      expect(described_class.origins).to eq("application" => 0, "scout" => 1)
      expect(described_class.statuses).to eq(
        "unmatched" => 0, "matched" => 1, "declined" => 2, "passed" => 3, "failed" => 4
      )
    end

    it "応募理由の番号が、設計書の表と一致する（並びは画面の順、番号は足した順）" do
      expect(CandidacyReason.reasons).to eq(
        "business" => 0, "industry" => 1, "job_major_category" => 11, "job_middle_category" => 2,
        "business_type" => 9, "work_process" => 3, "internship_details" => 4, "growth" => 10,
        "culture" => 5, "hourly_wage" => 6, "work_conditions" => 7, "technologies" => 8
      )
    end
  end

  describe "データベースの制約" do
    it "同じ募集×学生の2件目は、データベースが拒否する" do
      candidacy = create(:candidacy)

      expect {
        described_class.create!(job_posting: candidacy.job_posting, student_profile: candidacy.student_profile, origin: :scout)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    # update_columns は、モデルの検証を飛ばして SQL を直接送る（Django の QuerySet.update() に近い）。
    # データベースが一度拒否すると、そのテストの中ではそれ以上 SQL を送れなくなるので、1つのテストで1回だけ確かめる
    [0, 4096].each do |value|
      it "reason_mask が #{value}（1〜4095 の範囲外）なら、データベースが拒否する" do
        candidacy = create(:candidacy)

        expect { candidacy.update_columns(reason_mask: value) }.to raise_error(ActiveRecord::CheckViolation)
      end
    end

    it "reason_mask は、範囲内の値と空欄（理由なし）なら入る" do
      candidacy = create(:candidacy)

      expect { candidacy.update_columns(reason_mask: 4095) }.not_to raise_error
      expect { candidacy.update_columns(reason_mask: nil) }.not_to raise_error
    end
  end
end
