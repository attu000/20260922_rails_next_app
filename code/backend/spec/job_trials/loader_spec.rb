require "rails_helper"
require "tmpdir"
require Rails.root.join("db/job_trials/loader").to_s

# プチ職業体験の講座の読み込み（db/job_trials/loader.rb）のテスト。
# 本物の YAML が今のモデルの確かめをすべて通って入ること（文面を直したときの書き間違いに気づくため）、
# 何度読み込んでも同じ状態になり、データベースにしかないものは消さないこと（PR383）、誤りがあれば何も変えずに止まることを確かめる
RSpec.describe JobTrialLoader do
  describe "本物の YAML（db/job_trials/）" do
    # テストのデータベースにはマスタが入っていないので、db/seeds.rb を先に流す。seeds.rb の中で講座も読み込まれる
    before { Rails.application.load_seed }

    let(:job_trial) { JobTrial.find_by!(code: "qa-coupon") }

    it "テスト設計の講座が、ハードル4つ・工程のタグ2つと一緒に入る" do
      expect(job_trial).to have_attributes(title: "テスト設計", position: 1)
      expect(job_trial.job_middle_category.code).to eq("4-1")
      expect(job_trial.work_processes.map(&:name)).to contain_exactly("テスト計画・リスク評価", "テスト・評価")
      expect(job_trial.hurdles.map(&:code)).to eq(%w[understand enumerate specify judge])
      expect(job_trial.hurdles.map(&:position)).to eq([ 1, 2, 3, 4 ])
    end

    it "どのハードルも、正解の選択肢を選ぶと正解になる" do
      job_trial.hurdles.each do |hurdle|
        correct_key = hurdle.choices.find { |choice| choice["correct"] }["key"]
        expect(hurdle.check(correct_key)[:correct]).to be(true)
      end
    end

    it "もう一度読み込んでも増えず、同じ行のまま" do
      hurdle_ids = job_trial.hurdles.ids

      described_class.load!

      expect(JobTrial.count).to eq(1)
      expect(JobTrialHurdle.count).to eq(4)
      expect(JobTrialWorkProcess.count).to eq(2)
      expect(job_trial.reload.hurdles.ids).to eq(hurdle_ids)
    end

    it "データベースの文面が変わっていても、読み込み直すと YAML の文面で更新される。自己分析が指すハードルは壊れない" do
      hurdle = job_trial.hurdles.first
      hurdle.update!(name: "古い名前")
      self_analysis = create(:self_analysis, job_trial: job_trial, strength_hurdle: hurdle, growth_hurdle: hurdle)

      described_class.load!

      expect(hurdle.reload.name).to eq("理解する")
      expect(self_analysis.reload.strength_hurdle).to eq(hurdle)
    end

    it "YAML にないハードル・工程のタグは、ハードルは残し、工程のタグは YAML の内容に置き換える" do
      extra = create(:job_trial_hurdle, job_trial: job_trial, code: "extra", position: 5)
      job_trial.work_processes << create(:work_process)

      described_class.load!

      expect(JobTrialHurdle.exists?(extra.id)).to be(true)
      expect(job_trial.reload.work_processes.map(&:name)).to contain_exactly("テスト計画・リスク評価", "テスト・評価")
    end
  end

  describe "誤りのある YAML" do
    # 本物の YAML ではなく、一時的なフォルダの YAML を読ませる
    let(:directory) { Pathname.new(Dir.mktmpdir) }

    before do
      stub_const("JobTrialLoader::DIRECTORY", directory)
      create(:job_middle_category, code: "4-1")
      create(:work_process, name: "テスト・評価")
    end

    after { FileUtils.remove_entry(directory) }

    def valid_trial(code:)
      {
        "code" => code, "title" => "講座", "position" => 1, "job_middle_category_code" => "4-1",
        "work_processes" => [ "テスト・評価" ], "intro" => "はじめに",
        "hurdles" => [
          {
            "code" => "understand", "name" => "理解する", "overview" => "概要", "difficulty" => "難しさ",
            "tips" => "コツ", "example" => "具体例", "goal" => "ゴール", "question" => "問題",
            "choices" => [
              { "key" => "A", "body" => "選択肢A", "correct" => true, "explanation" => "Aの解説" },
              { "key" => "B", "body" => "選択肢B", "correct" => false, "explanation" => "Bの解説" }
            ]
          }
        ]
      }
    end

    def write_yaml(name, data)
      File.write(directory.join(name), data.to_yaml)
    end

    it "正しい YAML なら読み込め、読み込んだ講座の数を返す" do
      write_yaml("a.yml", valid_trial(code: "a"))

      expect(described_class.load!).to eq(1)
      expect(JobTrial.find_by!(code: "a").hurdles.count).to eq(1)
    end

    it "中分類の code が見つからなければ、ファイル名を添えて止まり、ほかのファイルの分も入らない" do
      write_yaml("a.yml", valid_trial(code: "a"))
      write_yaml("b.yml", valid_trial(code: "b").merge("job_middle_category_code" => "9-9"))

      expect { described_class.load! }.to raise_error(JobTrialLoader::Error, /b\.yml：中分類 9-9 が見つかりません/)
      expect(JobTrial.count).to eq(0)
    end

    it "工程の名前が見つからなければ止まる" do
      write_yaml("a.yml", valid_trial(code: "a").merge("work_processes" => [ "ない工程" ]))

      expect { described_class.load! }.to raise_error(JobTrialLoader::Error, /工程「ない工程」が見つかりません/)
    end

    it "工程が1つもなければ止まる" do
      write_yaml("a.yml", valid_trial(code: "a").merge("work_processes" => []))

      expect { described_class.load! }.to raise_error(JobTrialLoader::Error, /工程を1つ以上書いてください/)
    end

    it "書くべき項目がなければ止まる" do
      write_yaml("a.yml", valid_trial(code: "a").except("title"))

      expect { described_class.load! }.to raise_error(JobTrialLoader::Error, /a\.yml：title がありません/)
    end

    it "選択肢の正解が2つあれば、ハードルを保存できずに止まり、講座も入らない" do
      data = valid_trial(code: "a")
      data["hurdles"][0]["choices"][1]["correct"] = true
      write_yaml("a.yml", data)

      expect { described_class.load! }.to raise_error(JobTrialLoader::Error, /ハードル understandを保存できません/)
      expect(JobTrial.count).to eq(0)
    end
  end
end
