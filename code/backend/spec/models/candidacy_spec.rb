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

  # 候補者一覧の「メッセージ」のボタンを出すか（PR224）
  describe "#after_match?（マッチ以降か）" do
    { unmatched: false, declined: false, matched: true, passed: true, failed: true }.each do |status, expected|
      it "状態が #{status} なら #{expected}" do
        expect(described_class.new(origin: :application, status:).after_match?).to be(expected)
      end
    end
  end

  # 押せるボタンの判定（形D の available_actions。権限_バリデーション.md の 17-2-1）。
  # マッチ・スカウトは募集が掲載中のときだけ。見送り・取り消し・合格・不合格は、募集の状態を問わない（順11）
  describe ".available_actions_for（企業が今押せるボタン）" do
    let(:published) { create(:job_posting, :published) }
    let(:closed) { create(:job_posting, :closed) }

    it "やりとりがなく、募集が掲載中なら scout" do
      expect(described_class.available_actions_for(published, nil)).to eq([ "scout" ])
    end

    it "終了した募集は、やりとりがなければボタンなし" do
      expect(described_class.available_actions_for(closed, nil)).to eq([])
    end

    # 発生元 × 状態 → [掲載中の募集で押せるボタン, 終了した募集で押せるボタン]
    {
      %i[application unmatched] => [ %w[match decline], %w[decline] ],
      %i[application declined] => [ %w[match undo_decline], %w[undo_decline] ],
      %i[scout unmatched] => [ %w[decline], %w[decline] ],
      %i[scout declined] => [ %w[undo_decline], %w[undo_decline] ],
      %i[application matched] => [ %w[pass fail], %w[pass fail] ],
      %i[application passed] => [ %w[fail], %w[fail] ],
      %i[application failed] => [ %w[pass], %w[pass] ],
      %i[scout matched] => [ %w[pass fail], %w[pass fail] ]
    }.each do |(origin, status), (on_published, on_closed)|
      it "発生元が #{origin}、状態が #{status} なら、掲載中は #{on_published}、終了は #{on_closed}" do
        published_candidacy = create(:candidacy, job_posting: published, origin: origin, status: status)
        closed_candidacy = create(:candidacy, job_posting: closed, origin: origin, status: status)

        expect(described_class.available_actions_for(published, published_candidacy)).to eq(on_published)
        expect(described_class.available_actions_for(closed, closed_candidacy)).to eq(on_closed)
      end
    end
  end

  # 見送り・見送りの取り消し・合格・不合格（API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1。順11）。
  # 発生元・募集の状態を問わないので、終了した募集のやりとりで確かめる
  describe "見送り・見送りの取り消し・合格・不合格" do
    let(:closed) { create(:job_posting, :closed) }

    # 操作 → [できる状態と、そのあとの状態の組, できない状態]
    {
      decline: [ { unmatched: :declined }, %i[declined matched passed failed] ],
      undo_decline: [ { declined: :unmatched }, %i[unmatched matched passed failed] ],
      mark_passed: [ { matched: :passed, failed: :passed }, %i[unmatched declined passed] ],
      mark_failed: [ { matched: :failed, passed: :failed }, %i[unmatched declined failed] ]
    }.each do |operation, (allowed, forbidden)|
      describe "##{operation}" do
        allowed.each do |from, to|
          %i[application scout].each do |origin|
            it "発生元が #{origin}、状態が #{from} なら #{to} になる" do
              candidacy = create(:candidacy, job_posting: closed, origin: origin, status: from)

              candidacy.public_send(operation)

              expect(candidacy.reload.status).to eq(to.to_s)
            end
          end
        end

        forbidden.each do |from|
          it "状態が #{from} なら ConflictError で、状態は変わらない" do
            candidacy = create(:candidacy, job_posting: closed, status: from)

            expect { candidacy.public_send(operation) }.to raise_error(ConflictError)
            expect(candidacy.reload.status).to eq(from.to_s)
          end
        end
      end
    end

    it "合格・不合格にしても、マッチした日時は残る" do
      matched_at = 2.days.ago.change(usec: 0)
      candidacy = create(:candidacy, job_posting: closed, status: :matched, matched_at: matched_at)

      candidacy.mark_passed
      candidacy.mark_failed

      expect(candidacy.reload.matched_at).to eq(matched_at)
    end
  end

  # 候補者一覧に既定で出すやりとり（ページ設計.md の 6-5 C4）
  describe ".listed_in_company_candidacies（候補者一覧に既定で出すもの）" do
    it "未マッチとマッチだけを返し、見送り・合格・不合格は隠す" do
      shown = %i[unmatched matched].map { |status| create(:candidacy, status: status) }
      %i[declined passed failed].each { |status| create(:candidacy, status: status) }

      expect(described_class.listed_in_company_candidacies).to match_array(shown)
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

  # 理由の番号 i ごとに「2 の i 乗」を足し合わせる（データベース.md の 8-5 candidacies の reason_mask）
  describe "CandidacyReason.mask_for（理由の組を1つの数にする）" do
    it "理由が1つなら、その番号の桁だけが立つ" do
      expect(CandidacyReason.mask_for(%w[business])).to eq(1)
      expect(CandidacyReason.mask_for(%w[job_major_category])).to eq(2048)
    end

    it "事業内容（0）とカルチャー（5）なら 1 + 32 = 33" do
      expect(CandidacyReason.mask_for(%w[business culture])).to eq(33)
    end

    it "12個すべてなら 4095（データベースの範囲の上限）" do
      expect(CandidacyReason.mask_for(CandidacyReason.reasons.keys)).to eq(4095)
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
    [ 0, 4096 ].each do |value|
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
