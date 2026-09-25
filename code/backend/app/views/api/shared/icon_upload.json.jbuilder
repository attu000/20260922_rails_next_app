# ⑩ POST /api/company/profile/icon と ⑰ POST /api/student/profile/icon の形：{ "icon_url": "…" }
# （design/designs/API設計.md の 16-3 ⑩⑰）。@icon_owner は app/controllers/concerns/icon_upload.rb が入れる

json.partial! "api/shared/icon_url", record: @icon_owner
