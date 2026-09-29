require "rails_helper"
require "tmpdir"

# 講座の企業向けの説明（講座の YAML の guide。PR402・PR407）のテスト。
# 本物の YAML に書き漏れがないこと（文面を直したときの書き間違いに気づくため）と、書いていないときに壊れないことを確かめる
RSpec.describe JobTrialGuide do
  describe "本物の YAML（db/job_trials/）" do
    it "すべての講座に説明があり、すべてのハードルの code に力・説明・まとめがそろっている" do
      guides = described_class.all

      Dir.glob(described_class::DIRECTORY.join("*.yml")).each do |path|
        data = YAML.safe_load_file(path)
        guide = guides[data["code"]]
        expect(guide).to be_present, "#{File.basename(path)} に guide がありません"
        expect(guide.summary).to be_present

        data["hurdles"].each do |hurdle|
          values = guide.hurdle(hurdle["code"])
          expect(values.keys).to match_array(described_class::HURDLE_KEYS), "#{hurdle['code']} の説明が足りません"
          expect(values.values).to all(be_present)
        end
      end
    end
  end

  describe "書いていないとき" do
    # 本物ではなく、一時的なフォルダの YAML を読ませる
    let(:directory) { Pathname.new(Dir.mktmpdir) }

    before { stub_const("JobTrialGuide::DIRECTORY", directory) }

    after { FileUtils.remove_entry(directory) }

    it "guide のない講座は入らない" do
      File.write(directory.join("a.yml"), { "code" => "a", "title" => "講座" }.to_yaml)

      expect(described_class.all).to eq({})
    end

    it "書いていないハードルは空の対応表を返す" do
      File.write(directory.join("a.yml"), {
        "code" => "a",
        "guide" => { "summary" => "説明", "hurdles" => { "understand" => { "skill" => "力" } } }
      }.to_yaml)

      guide = described_class.all.fetch("a")
      expect(guide.summary).to eq("説明")
      expect(guide.hurdle("understand")).to eq("skill" => "力")
      expect(guide.hurdle("judge")).to eq({})
    end
  end
end
