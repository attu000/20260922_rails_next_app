# 推薦の集計のうち、件数（interest_count）と self_weight を、やりとりの表から数え直す（処理設計_類似度.md の 7-2・7-5）。
# 学生の集計（StudentRecommendationStat）と募集の集計（JobPostingRecommendationStat）で使う。
# 2つは同じ計算を、学生の列と募集の列を入れ替えて行うだけなので、ここ1か所に書き、どちらの列でまとめるかを各モデルが指定する。
#   学生側：件数 |A(S)|、self_weight W(S) = S が興味を示した募集 P ごとの u(P) = 1 / log(1 + |B(P)|) の合計
#   募集側：件数 |B(P)|、self_weight W(P) = P に興味を示した学生 S ごとの u(S) = 1 / log(1 + |A(S)|) の合計
# 件数と self_weight は、上限（L_P・L_S）をかけずに全員分で数える（7-2）。
# Django でいえば、2つのモデルに同じクラスメソッドを持たせる Mixin にあたる
module InterestStats
  extend ActiveSupport::Concern

  class_methods do
    # どちらの列でまとめるかを指定する。own は自分（集計の行の持ち主）の列、other は相手の列。
    # 例：学生の集計なら interest_stats_columns own: :student_profile_id, other: :job_posting_id
    def interest_stats_columns(own:, other:)
      @interest_own_column = own
      @interest_other_column = other
    end

    # 渡された番号の行の、件数と self_weight を数え直して上書きする。
    # 行がなければ作り（項目数はデータベースの既定値0のまま）、あれば件数と self_weight の列だけを書き換える。
    # 興味が0件の番号も0で上書きする。何度呼んでも同じ結果になる（PR276）
    def refresh_interests!(ids)
      ids = Array(ids).map(&:to_i).uniq
      return if ids.empty?

      own = @interest_own_column
      other = @interest_other_column
      mine = Candidacy.interests.where(own => ids)

      # 1. 件数：自分の列ごとに、興味を示したやりとりを数える。{ 番号 => 件数 }
      counts = mine.group(own).count

      # 2. 相手ごとの興味の数：渡された番号が興味を示した相手だけについて、その相手に興味を示した全員を数える
      other_counts = Candidacy.interests
                              .where(other => mine.select(other))
                              .group(other)
                              .select(other, "COUNT(*) AS interest_count")

      # 3. self_weight：自分の列ごとに、相手の 1 / log(1 + 相手の興味の数) を合計する。{ 番号 => 合計 }。
      #    相手の興味の数は自分を含むので1以上になり、log(2) 以上で割ることになる（0で割ることはない）
      weights = mine
                .joins("INNER JOIN (#{other_counts.to_sql}) AS others ON others.#{other} = candidacies.#{other}")
                .group(own)
                .sum(Arel.sql("1 / LN(1 + others.interest_count::double precision)"))

      rows = ids.map do |id|
        { own => id, interest_count: counts.fetch(id, 0), self_weight: weights.fetch(id, 0).to_f }
      end
      # なければ作り、あれば書き換える（Django の bulk_create(update_conflicts=True) にあたる）
      upsert_all(rows, unique_by: own, update_only: %i[interest_count self_weight])
    end
  end
end
