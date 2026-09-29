require "rails_helper"

# 自己分析のテスト。入力の決まり（PR391）、選んだハードルがその講座のものか、
# 「あれば上書き、なければ作る」保存（PR371）、得意を伸ばしたいかの判定（PR360）を確かめる
RSpec.describe SelfAnalysis, type: :model do
  let(:job_trial) { create(:job_trial, :with_hurdles) }
  let(:hurdles) { job_trial.hurdles.to_a }
  let(:student_profile) { create(:student_user).student_profile }
  let(:valid_attributes) do
    {
      strength_hurdle_id: hurdles[0].id,
      strength_reason: "仕様の言葉を確かめる癖があるから",
      growth_hurdle_id: hurdles[3].id,
      growth_reason: "curiosity",
      growth_detail: "原因を順に消していくのが楽しい",
      next_step: "不具合の報告の書き方を知りたい"
    }
  end

  def save_with(overrides = {})
    described_class.save_for(student_profile, job_trial, valid_attributes.merge(overrides))
  end

  describe ".save_for（保存）" do
    it "正しい値なら保存できる" do
      self_analysis = save_with

      expect(self_analysis).to be_persisted
      expect(self_analysis).to have_attributes(
        strength_hurdle: hurdles[0], growth_hurdle: hurdles[3], growth_reason: "curiosity",
        strength_reason: "仕様の言葉を確かめる癖があるから"
      )
    end

    it "2回目は上書きし、1人×1講座に1件のまま" do
      first = save_with
      second = save_with(growth_hurdle_id: hurdles[1].id, growth_reason: "future", next_step: "書き直した")

      expect(second.id).to eq(first.id)
      expect(described_class.where(student_profile: student_profile, job_trial: job_trial).count).to eq(1)
      expect(second.reload).to have_attributes(growth_hurdle: hurdles[1], growth_reason: "future", next_step: "書き直した")
    end

    it "ほかの講座なら、別の自己分析として作る" do
      save_with
      other_trial = create(:job_trial, :with_hurdles)
      other_hurdles = other_trial.hurdles.to_a
      other = described_class.save_for(student_profile, other_trial,
                                       valid_attributes.merge(strength_hurdle_id: other_hurdles[0].id,
                                                              growth_hurdle_id: other_hurdles[1].id))

      expect(other).to be_persisted
      expect(student_profile.self_analyses.count).to eq(2)
    end

    it "誤りがあれば保存せず、エラーを持ったまま返す。前の自己分析は変わらない" do
      save_with
      result = save_with(next_step: "")

      expect(result.errors[:next_step]).to be_present
      expect(described_class.find_by(student_profile: student_profile, job_trial: job_trial).next_step)
        .to eq("不具合の報告の書き方を知りたい")
    end

    it "同時に2回送られて「1人×1講座に1件」に弾かれたら、ConflictError を投げる（窓口では 409）" do
      save_with
      # 先に探したときにはまだなかった（同時に送られた）状態を作るため、探す処理が新しい自己分析を返すようにする
      allow(described_class).to receive(:find_or_initialize_by) do |attributes|
        described_class.new(attributes)
      end

      expect { save_with }.to raise_error(ConflictError)
      expect(described_class.count).to eq(1)
    end

    it "受け取る項目のほかは無視する（学生や講座を送っても変わらない）" do
      other_student = create(:student_user).student_profile
      self_analysis = save_with(student_profile_id: other_student.id)

      expect(self_analysis.reload.student_profile).to eq(student_profile)
    end
  end

  describe "ハードルの確かめ" do
    it "ほかの講座のハードルは誤り" do
      other_hurdle = create(:job_trial, :with_hurdles).hurdles.first
      result = save_with(strength_hurdle_id: other_hurdle.id)

      expect(result).not_to be_persisted
      expect(result.errors.to_hash(true)).to eq(strength_hurdle_id: [ "得意なハードルは、この講座のハードルから選んでください" ])
    end

    it "ない番号も同じ誤り" do
      result = save_with(growth_hurdle_id: 0)

      expect(result.errors.to_hash(true)).to eq(growth_hurdle_id: [ "伸ばしたいハードルは、この講座のハードルから選んでください" ])
    end

    it "空なら「入力してください」" do
      result = save_with(strength_hurdle_id: nil)

      expect(result.errors.to_hash(true)).to eq(strength_hurdle_id: [ "得意なハードルを入力してください" ])
    end
  end

  describe "理由の種類の確かめ" do
    it "5つのどれかなら通る" do
      %w[challenge curiosity importance future other].each do |reason|
        expect(save_with(growth_reason: reason)).to be_persisted
      end
    end

    it "知らない値は誤り" do
      expect(save_with(growth_reason: "unknown").errors[:growth_reason]).to be_present
    end

    it "空なら「入力してください」" do
      expect(save_with(growth_reason: nil).errors.to_hash(true)).to eq(growth_reason: [ "伸ばしたい理由を入力してください" ])
    end
  end

  describe "記述3つの確かめ（PR391）" do
    %i[strength_reason growth_detail next_step].each do |attribute|
      it "#{attribute}：空・空白だけは「入力してください」" do
        expect(save_with(attribute => "").errors[attribute]).to be_present
        expect(save_with(attribute => "  \n ").errors[attribute]).to be_present
      end

      it "#{attribute}：400文字は通り、401文字は誤り" do
        expect(save_with(attribute => "あ" * 400)).to be_persisted
        expect(save_with(attribute => "あ" * 401).errors[attribute]).to be_present
      end
    end
  end

  describe "#same_hurdle?（得意を伸ばしたい学生か）" do
    it "得意と伸ばしたいが同じハードルなら true" do
      expect(save_with(growth_hurdle_id: hurdles[0].id).same_hurdle?).to be(true)
    end

    it "違うハードルなら false" do
      expect(save_with.same_hurdle?).to be(false)
    end
  end

  it "学生×講座で2件目を直接作ると、データベースの決まり（UNIQUE）に弾かれる（同時に2回送られたとき。窓口は 409 にする）" do
    first = create(:self_analysis)
    duplicate = build(:self_analysis, student_profile: first.student_profile, job_trial: first.job_trial)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
