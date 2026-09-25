# ⑩ POST /api/company/profile/icon の形：{ "icon_url": "…" }（design/designs/API設計.md の 16-3 ⑩）

json.partial! "api/shared/icon_url", record: @company
