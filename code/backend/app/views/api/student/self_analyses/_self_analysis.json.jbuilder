# 自己分析の形（design/designs/API設計.md の 16-3-9 ㊽）。㊻ の self_analysis と、㊽ の返事で使う

json.extract! self_analysis,
              :job_trial_id,
              :strength_hurdle_id, :strength_reason,
              :growth_hurdle_id, :growth_reason, :growth_detail,
              :next_step
# 1-1 と 2-1 が同じハードルか（「得意を伸ばしたい」学生か。判定は Rails。PR360）
json.same_hurdle self_analysis.same_hurdle?
json.extract! self_analysis, :created_at, :updated_at
