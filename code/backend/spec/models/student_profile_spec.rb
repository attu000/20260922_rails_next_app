require "rails_helper"

# 学生プロフィールまわりのモデルのテスト。
# - データベースの CHECK：モデルの検証をすり抜けても、データベースが「どちらか一方だけ」や値の範囲の決まりを守ること
# - 働き方の好み（性格の5軸。順9）と、興味のある業界（順10）の保存
# 詳しくは design/designs/データベース.md の 8-5 student_profiles・student_skills
RSpec.describe StudentProfile, type: :model do
  let(:profile) { create(:student_user).student_profile }
  let(:technology) { create(:technology) }

  # 企業に見せる最終活動の目安（その他決め事.md の 5-4。【仕上げ】順16）
  describe "#last_active_range（最終活動の目安）" do
    {
      0 => "within_3_days",
      3 => "within_3_days",
      4 => "within_7_days",
      7 => "within_7_days",
      8 => "within_30_days",
      30 => "within_30_days",
      31 => "over_30_days"
    }.each do |days_ago, range|
      it "最終活動日が#{days_ago}日前なら #{range}" do
        profile.user.update!(last_active_on: Time.zone.today - days_ago)

        expect(profile.last_active_range).to eq(range)
      end
    end

    it "最終活動日が空（一度もログインしていない）なら nil（PR335）" do
      profile.user.update!(last_active_on: nil)

      expect(profile.last_active_range).to be_nil
    end
  end

  describe "データベースの CHECK（プログラミング歴は、技術か「その他」の名前のどちらか一方だけ）" do
    # save(validate: false) は、モデルの検証を飛ばして保存する
    it "技術も「その他」の名前もない行は、データベースが拒否する" do
      skill = StudentSkill.new(student_profile: profile, level: :v1)

      expect { skill.save(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
    end

    it "技術と「その他」の名前の両方がある行は、データベースが拒否する" do
      skill = StudentSkill.new(student_profile: profile, technology: technology, other_name: "Elm", level: :v1)

      expect { skill.save(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "データベースの CHECK（一覧の大学と大学名（その他）は、両方同時に入らない）" do
    # update_columns は、モデルの検証も保存前の処理も飛ばして、SQL を直接送る（Django の QuerySet.update() に近い）
    it "両方を入れようとすると、データベースが拒否する" do
      university = create(:university)

      expect { profile.update_columns(university_id: university.id, university_other_name: "海外の大学") }
        .to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "データベースの CHECK（働き方の好みは −2〜2）" do
    it "範囲の外の値を、検証を通さずに書き込もうとすると、データベースが拒否する" do
      expect { profile.update_columns(personality_pace: 3) }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  # 窓口が働き方の好みを受け取るのは 9-3 からなので、ここではモデルを直接呼んで確かめる
  describe "#save_profile（働き方の好み）" do
    it "範囲の外（3）だと保存されない" do
      result = profile.save_profile(personality_pace: 3)

      expect(result).to be(false)
      expect(profile.errors.full_messages_for(:personality_pace)).to eq([ "働き方の好み（進め方）は2以下の値にしてください" ])
      expect(profile.reload.personality_pace).to eq(0)
    end

    it "範囲の中（−2）なら保存される" do
      result = profile.save_profile(personality_pace: -2)

      expect(result).to be(true)
      expect(profile.reload.personality_pace).to eq(-2)
    end
  end

  # 窓口が興味のある業界を受け取るのは 10-2 からなので、ここではモデルを直接呼んで確かめる
  describe "#save_profile（興味のある業界。PR254）" do
    let(:industries) { create_list(:industry, 2) }

    it "送った業界の一覧で丸ごと置き換える" do
      profile.save_profile(interested_industry_ids: [ industries.first.id ])

      result = profile.save_profile(interested_industry_ids: industries.map(&:id))

      expect(result).to be(true)
      expect(profile.reload.interested_industry_ids).to match_array(industries.map(&:id))
    end

    it "送らなければ変えない" do
      profile.save_profile(interested_industry_ids: [ industries.first.id ])

      profile.save_profile(name: "新しい名前")

      expect(profile.reload.interested_industry_ids).to eq([ industries.first.id ])
    end

    it "一覧にない番号があると保存されない" do
      result = profile.save_profile(interested_industry_ids: [ industries.first.id, 0 ])

      expect(result).to be(false)
      expect(profile.errors.full_messages_for(:interested_industry_ids)).to eq([ "興味のある業界に選べない値が含まれています" ])
      expect(profile.reload.interested_industry_ids).to eq([])
    end
  end

  # 順17：就活希望エリア・外部リンク・資格（【仕上げ】）
  describe "#save_profile（就活希望エリア・外部リンク・資格）" do
    let(:prefectures) { create_list(:prefecture, 2) }
    let(:full_attributes) do
      {
        job_hunting_prefecture_ids: prefectures.map(&:id),
        links: [ { url: "https://github.com/example", title: "GitHub" }, { url: "http://example.com/works", title: " " } ],
        certifications: [ "基本情報技術者", "TOEIC 800点" ]
      }
    end

    it "3つとも保存でき、リンクと資格は送った順のまま。表示名が空白だけなら空欄にそろえる" do
      result = profile.save_profile(full_attributes)

      expect(result).to be(true)
      profile.reload
      expect(profile.job_hunting_prefecture_ids).to match_array(prefectures.map(&:id))
      expect(profile.student_links.map { |link| [ link.url, link.title ] })
        .to eq([ [ "https://github.com/example", "GitHub" ], [ "http://example.com/works", nil ] ])
      expect(profile.student_certifications.map(&:name)).to eq([ "基本情報技術者", "TOEIC 800点" ])
    end

    it "送り直すと置き換わり、送らなかった項目は変わらない" do
      profile.save_profile(full_attributes)

      profile.save_profile(links: [ { url: "https://example.com/portfolio" } ], certifications: [])

      profile.reload
      expect(profile.student_links.map(&:url)).to eq([ "https://example.com/portfolio" ])
      expect(profile.student_certifications).to be_empty
      expect(profile.job_hunting_prefecture_ids).to match_array(prefectures.map(&:id))
    end

    # PR338：http:// か https:// で始まり、その後ろに空白でない文字が続くこと
    it "URL の形と長さを確かめ、行の番号を付けた名前で誤りを返す" do
      links = [
        { url: "HTTPS://example.com" },
        { url: "https://" },
        { url: "https://example.com/a b" },
        { url: "ftp://example.com" },
        { url: "" },
        # 「https://example.com/」の20文字 ＋ 481文字 ＝ 501文字
        { url: "https://example.com/#{"a" * 481}" },
        { url: "https://example.com", title: "a" * 101 }
      ]

      result = profile.save_profile(links: links)

      expect(result).to be(false)
      # to_hash(true) は、項目名を付けた文（「URLを入力してください」）で返す
      expect(profile.errors.to_hash(true)).to eq(
        "links[1].url": [ "URLはhttp://かhttps://で始まる形で入力してください" ],
        "links[2].url": [ "URLはhttp://かhttps://で始まる形で入力してください" ],
        "links[3].url": [ "URLはhttp://かhttps://で始まる形で入力してください" ],
        "links[4].url": [ "URLを入力してください" ],
        "links[5].url": [ "URLは500文字以内で入力してください" ],
        "links[6].title": [ "表示名は100文字以内で入力してください" ]
      )
    end

    it "資格名が空（空白だけも）や101文字なら誤り" do
      result = profile.save_profile(certifications: [ "基本情報技術者", " ", "a" * 101 ])

      expect(result).to be(false)
      expect(profile.errors.full_messages_for(:"certifications[1].name")).to eq([ "資格名を入力してください" ])
      expect(profile.errors.full_messages_for(:"certifications[2].name")).to eq([ "資格名は100文字以内で入力してください" ])
    end

    it "外部リンクは21件、資格は51件から誤り" do
      result = profile.save_profile(
        links: Array.new(21) { |index| { url: "https://example.com/#{index}" } },
        certifications: Array.new(51) { |index| "資格#{index}" }
      )

      expect(result).to be(false)
      expect(profile.errors.full_messages_for(:links)).to eq([ "外部リンクは20件までにしてください" ])
      expect(profile.errors.full_messages_for(:certifications)).to eq([ "資格は50件までにしてください" ])
    end

    it "一覧にない都道府県の番号があると誤り" do
      result = profile.save_profile(job_hunting_prefecture_ids: [ prefectures.first.id, 0 ])

      expect(result).to be(false)
      expect(profile.errors.full_messages_for(:job_hunting_prefecture_ids)).to eq([ "就活希望エリアに選べない値が含まれています" ])
    end

    it "どこかに誤りがあれば、ほかの項目も含めて何も書き込まない" do
      profile.save_profile(full_attributes)

      result = profile.save_profile(name: "新しい名前", certifications: [ "新しい資格" ], links: [ { url: "no-scheme" } ])

      expect(result).to be(false)
      profile.reload
      expect(profile.name).not_to eq("新しい名前")
      expect(profile.student_certifications.map(&:name)).to eq([ "基本情報技術者", "TOEIC 800点" ])
      expect(profile.student_links.size).to eq(2)
    end
  end

  # 順12：推薦の集計の項目数は、付属テーブルと同じトランザクションで数え直す（処理設計_類似度.md の 7-5）
  describe "#save_profile（推薦の集計の項目数）" do
    let(:middles) { create_list(:job_middle_category, 2) }
    let(:industry) { create(:industry) }

    it "保存すると、集計の行ができ、項目数が入力どおりになる。変えて保存し直すと、項目数も変わる" do
      profile.save_profile(interested_job_middle_category_ids: middles.map(&:id), interested_industry_ids: [ industry.id ])
      expect(profile.reload.recommendation_stat).to have_attributes(job_middle_category_count: 2, industry_count: 1)

      profile.save_profile(interested_job_middle_category_ids: [ middles.first.id ], interested_industry_ids: [])

      expect(profile.reload.recommendation_stat).to have_attributes(job_middle_category_count: 1, industry_count: 0)
    end

    it "項目に関係のない保存（氏名だけ）でも、項目数は正しいまま" do
      profile.save_profile(interested_job_middle_category_ids: middles.map(&:id))

      profile.save_profile(name: "新しい名前")

      expect(profile.reload.recommendation_stat.job_middle_category_count).to eq(2)
    end

    it "入力に誤りがあって保存できなかったときは、項目数も変わらない" do
      profile.save_profile(interested_industry_ids: [ industry.id ])

      result = profile.save_profile(interested_job_middle_category_ids: middles.map(&:id), interested_industry_ids: [ 0 ])

      expect(result).to be(false)
      expect(profile.reload.recommendation_stat).to have_attributes(job_middle_category_count: 0, industry_count: 1)
    end
  end
end
