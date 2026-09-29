require "rails_helper"

# プチ職業体験のハードルのテスト。問題の正否の判定（PR377）と、選択肢の形の確かめ（YAML の書き間違いを止める）を確かめる
RSpec.describe JobTrialHurdle, type: :model do
  describe "#check（正否の判定）" do
    let(:hurdle) { create(:job_trial_hurdle) }

    it "正解の選択肢なら、正解と、その選択肢の解説を返す" do
      expect(hurdle.check("A")).to eq(correct: true, explanation: "Aの解説")
    end

    it "不正解の選択肢なら、不正解と、その選択肢の解説を返す（正解の選択肢は返さない）" do
      expect(hurdle.check("B")).to eq(correct: false, explanation: "Bの解説")
    end

    it "その問題にない選択肢なら nil を返す" do
      expect(hurdle.check("Z")).to be_nil
    end

    it "選択肢の項目名を記号で入れても、保存前から同じように判定できる" do
      hurdle = build(:job_trial_hurdle, choices: [
        { key: "A", body: "選択肢A", correct: false, explanation: "Aの解説" },
        { key: "B", body: "選択肢B", correct: true, explanation: "Bの解説" }
      ])

      expect(hurdle).to be_valid
      expect(hurdle.check("B")).to eq(correct: true, explanation: "Bの解説")
    end
  end

  describe "選択肢の形の確かめ" do
    def choice(key, correct:)
      { "key" => key, "body" => "選択肢#{key}", "correct" => correct, "explanation" => "#{key}の解説" }
    end

    it "正解がちょうど1つで、key が重複しなければ保存できる" do
      expect(build(:job_trial_hurdle, choices: [ choice("A", correct: false), choice("B", correct: true) ])).to be_valid
    end

    it "正解が0個なら保存できない" do
      hurdle = build(:job_trial_hurdle, choices: [ choice("A", correct: false), choice("B", correct: false) ])

      expect(hurdle).not_to be_valid
      expect(hurdle.errors[:choices]).to be_present
    end

    it "正解が2個なら保存できない" do
      expect(build(:job_trial_hurdle, choices: [ choice("A", correct: true), choice("B", correct: true) ])).not_to be_valid
    end

    it "key が重複していれば保存できない" do
      expect(build(:job_trial_hurdle, choices: [ choice("A", correct: true), choice("A", correct: false) ])).not_to be_valid
    end

    it "項目が欠けた選択肢（解説がない）があれば保存できない" do
      broken = choice("B", correct: false).except("explanation")

      expect(build(:job_trial_hurdle, choices: [ choice("A", correct: true), broken ])).not_to be_valid
    end

    it "correct が真偽でなければ保存できない" do
      expect(build(:job_trial_hurdle, choices: [ choice("A", correct: true), choice("B", correct: "no") ])).not_to be_valid
    end

    it "選択肢が空の配列や、配列でないなら保存できない" do
      expect(build(:job_trial_hurdle, choices: [])).not_to be_valid
      expect(build(:job_trial_hurdle, choices: { "key" => "A" })).not_to be_valid
    end
  end

  it "同じ講座の中で code が重複すれば保存できない（ほかの講座となら重複してよい）" do
    first = create(:job_trial_hurdle, code: "understand")

    expect(build(:job_trial_hurdle, job_trial: first.job_trial, code: "understand")).not_to be_valid
    expect(build(:job_trial_hurdle, code: "understand")).to be_valid
  end
end
