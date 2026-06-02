# Phase 1 重建设计(全新 schema + 全新前端)

> 取代 `docs/phase1-impl-plan.md`(那份"组装"路线作废)。
> 方向决策:**①全新干净 schema(概念词汇)②保留/迁移现有数据 ③全新组件+路由**。
> 概念依据:`docs/phase1-concept.md`。
> **本文是签字稿:schema 经确认后才会写 live 迁移。** 现有 `stater_*`/`open_need`/`skillcard_request` 等旧结构逐步退役,数据迁入新表。

---

## 设计原则

1. **词汇即表名** —— 表/列/RPC 直接用概念语言:card / slot / aspect / resource / forge / work / settle。读 schema = 读概念。
2. **一个 Forge 队列** —— 所有"造/改卡"(成员卡、徽章、资源、需求、认领、铸成)统一成**一张 `forge_request` 表**,一个审批入口。取代分散的 skillcard_request + resource.approval_status + 状态流转。
3. **monthly_quota 是数字** —— 资源额度是权威数字列,容量校验按数字算。
4. **nominal 不落表,liquid 落账** —— nominal = Σ(work 月度铸值) 实时算;liquid = `str_ledger` append-only。
5. **数据保留** —— 每个旧表→新表有明确迁移映射,迁移脚本可重跑、可校验。

---

## 目标 schema

> 标注:**KEEP**=沿用 / **REBUILD**=新建结构并迁数据 / **NEW**=全新 / **RETIRE**=数据迁出后弃用。

### A. 卡 · 身份(Agent / Credential)

**`member`** — Agent 成员卡 · **KEEP**
`id, auth_user_id(NULL=卡), full_name, email UNIQUE, affiliation, avatar_url, bio, links jsonb, kind('operator'|'card'), home_unit_id→org_unit, status, created_at`
> 已是干净的"行动者句柄",不动。

**`badge`** — Credential 徽章(技艺 access 相位)· **REBUILD**(自 `member_skill`)
`member_id→member, skill_id→skill, level guild_level(apprentice|journeyman|craftsman|master), forged_at, forge_request_id→forge_request`
迁移:`member_skill.certified_level` → `badge.level`(丢弃死列 `self_level`)。
**`skill`** — KEEP(技能目录,leaf 校验)。

### B. 组织(Chapter / WG / Officer)

**`org_unit`** KEEP(`kind chapter|working_group`)· **`org_unit_officer`** KEEP(chair/secretary/leader)· **`org_unit_member`** KEEP。

### C. 槽 · 项目(Slot)

**`project`** — Slot 卡 · **KEEP+精简**
`id, name, status_id→project_status, venue_id, deadline, summary, links jsonb, org_unit_id→org_unit(WG,认领即设此列), created_at`

**`project_slot`** — **NEW**(统一固有角色槽 + 需求槽,取代 `open_need`/`need_application`/角色座位散落)
```
id, project_id→project,
slot_kind text CHECK ('leader','work_labor','work_resource'),
  -- leader=一作(固有,1);work_labor=工时需求→co-author;work_resource=资源需求→通讯/末位候选
req_access  guild_level NULL,    -- 进槽需达的徽章级(技艺门槛)
skill_id    uuid NULL→skill,     -- work_labor 指定技能
resource_type_id uuid NULL,      -- work_resource 指定资源类型
quota       numeric NULL,        -- 需求的月度额度(工时/单位)
headcount   int default 1,
authorship  text CHECK ('first','co','last_candidate') -- 由 slot_kind 推导,落库便于结算
status      text CHECK ('open','filled','closed'),
created_via uuid→forge_request,  -- 发需求=一次 Forge
created_at
```
> 「发需求」= 插一行 `project_slot`(open)。Leader 槽在 admin 预铸项目时即建。

### D. 资源(全托管月度额度卡)

**`resource`** — **REBUILD**(自旧 `resource`)
```
id, type_id→resource_type, name,
holder_member_id→member NOT NULL,        -- 社区内托管人,唯一负责人
scope text CHECK ('member','community'),
monthly_quota numeric NOT NULL,          -- 权威月度额度(数字)
unit text, usd_per_unit numeric, str_per_unit numeric,
forge_request_id→forge_request,          -- 审批来源(替代 approval_status 列)
created_at
```
迁移:`monthly_quota = _capacity_num(old.capacity)`;`approval_status='approved'` 的转为已批 forge_request,pending 的建 submitted forge_request。**owner 不建模**(仅 holder)。
**`resource_type`** KEEP(含 time/compute/data/fund 归一;valuation 字段保留)。
> 工时也是资源:`resource_type = time`,holder 默认本人。

### E. Forge(统一审批请求)

**`forge_request`** — **NEW**(取代 `skillcard_request` + resource 审 + 状态流转审)
```
id,
target_type text CHECK ('member_card','badge','resource','need','claim','project_done'),
action text CHECK ('create','update'),
target_id uuid NULL,             -- update 时指向被改对象;create 时 NULL,批准后回填
payload jsonb,                   -- 造/改的字段
batch_id uuid NULL,              -- 一次 forge 多徽章=一批
fee int default 0,
submitted_by→member, submitted_as→member NULL,  -- act-as 卡
status text CHECK ('submitted','approved','rejected','cancelled'),
reviewed_by→member, review_note, created_at, settled_at
```
迁移:旧 `skillcard_request` 行 → `forge_request(target_type='badge')`;resource approval 状态 → 对应 forge_request。
> **认领**(claim)= `target_type='claim'` 的 forge,**本组内自助即时批**(officer 自己是 reviewer)。

### F. Work(进槽 + 月度承诺)

**`work_commitment`** — **REBUILD**(取代 `stater_project_stake_commitment` + `stater_commitment_period`)
```
id, slot_id→project_slot, member_id→member(进槽的卡),
resource_id→resource NULL,       -- 用哪张资源卡(含 time)承诺
year_month text,                 -- 'YYYY-MM'
monthly_amount numeric,          -- 本月承诺额度(工时/单位)
nominal_str int,                 -- 本月铸的名义 STR(锁定)
approval text CHECK ('ok','needs_review','approved','rejected'), -- 越容量队列
created_at, UNIQUE(slot_id, member_id, year_month)
```
容量校验:`Σ(member 某 resource 某 year_month 的 monthly_amount) ≤ resource.monthly_quota` → 越则 `needs_review`。
> 进槽 = 插 work_commitment(够量即时 / 越容量进 forge 之外的 capacity 队列)。leader/seat 类无额度的进槽 = `project_slot.status='filled'` + 无 work_commitment 或额度 0。

### G. Settle · STR

**`str_account`** KEEP(member/project_escrow/treasury)· **`str_ledger`** KEEP(自 `stater_ledger`,append-only liquid)。
**`settlement`** / **`settlement_item`** — **KEEP+精简**(gated `project_status='Finished'`)
`settlement_item: member_id, slot_id, is_author bool, author_order int, payout int, notes`
> nominal→liquid 仅在 `project_done` Forge 过审触发 Settle。nominal 实时 = Σ `work_commitment.nominal_str`(该项目)。
**`str_policy`** KEEP(费率/额度参数)。**RETIRE**:`stater_project_stake_commitment`、`stater_commitment_period`、`open_need`、`need_application`、`member_skill`、`skillcard_request`、`resource.capacity`(数据迁出后)。

---

## 老 → 新 迁移映射(总表)

| 旧 | 新 | 转换 |
|---|---|---|
| member | member | 不变 |
| member_skill.certified_level | badge.level | 直迁,丢 self_level |
| skillcard_request | forge_request(target_type=badge) | 状态映射 submitted/approved/rejected |
| resource(+approval_status,capacity) | resource(monthly_quota)+forge_request | quota=_capacity_num(capacity);approval→forge |
| open_need / need_application | project_slot(work_*)+work_commitment | kind 由 contribution_kind 映射 |
| 项目 leader 座位(can_manage project_member) | project_slot(leader,filled) | leader→first author |
| stater_project_stake_commitment | work_commitment(+ slot) | 按 commitment_type 映射 slot_kind |
| stater_commitment_period | work_commitment(year_month,nominal_str) | token_equivalent→nominal_str |
| stater_ledger | str_ledger | 改名直迁 |
| stater_settlement(_item) | settlement(_item) | 精简列 |
| org_unit* / project / skill / str_policy | 同名 KEEP | 不变 |

迁移脚本策略:**一份幂等迁移**(新表 `create if not exists` → `insert ... select` 从旧表 → 校验行数 → 旧表标记 deprecated 但不 drop,留回滚窗口)。先本地 admin 跑、校验,再保留旧表一段时间。

---

## RPC 表面(概念命名)

```
forge_member_card(full_name,email,unit,affiliation,badges jsonb)   -- create/update Agent
forge_badge(member, skill, level, as)        -- 提交徽章 forge(batch 版 forge_badges)
forge_resource(type, name, holder, scope, monthly_quota, ...)      -- 提交资源 forge
forge_need(project, slot_kind, req_access, skill/resource_type, quota, headcount) -- 发需求
forge_claim(project, wg_unit)                -- 认领=设 project.org_unit_id(本组自助即时)
forge_project_done(project)                  -- 铸成→触发 settle
review_forge(request_id, approve, note)      -- 统一审批(一个队列)
work_seat(slot, member, resource, year_month, monthly_amount, as)  -- 进槽+月度承诺
review_capacity(commitment_id, approve)      -- 越容量队列决策
submit_settlement / approve_settlement       -- KEEP(gated Finished)
```
权限沿用现有 `has_capability` / `is_unit_officer` / `manages_*` 判定(C 层不变)。

---

## 全新前端架构

**新路由(officer 控制台,取代散在 UnitDetail/ProjectDetail 的逻辑):**
```
/officer                      → 按身份分流到下面两个台
/officer/chapter/[unitId]     → 卡牌册(Chapter officer)
/officer/wg/[unitId]          → 槽板(WG officer)
/admin/forge-queue            → 统一 Forge 审批台(取代 approvals 多队列散口)
```
**新组件(`src/lib/cards/`):**
```
CardBinder.svelte      折叠卡册容器(Chapter)
MemberCard.svelte      成员卡:头像+徽章+容量条(monthly_quota)+承诺片
CommitChip.svelte      承诺片(项目·额度·改)
Matcher.svelte         [+投入项目] 匹配抽屉(三层筛+灰显+紧急度排序,双向)
SlotBoard.svelte       槽板容器(WG)
ProjectSlotCard.svelte 项目卡:座位图+需求槽+发需求+铸成入口
ForgeCard.svelte       铸卡表单(成员/徽章/资源/需求 统一壳)
ForgeQueue.svelte      统一审批列表
```
**保留(officer 个人参与面,只读):** `/`(portfolio)、`/wallet`、`/members/[id]`。
**设计语言:** 沿用 app.css 暗色交易终端;技艺=teal、信誉=gold、liquid=green、nominal=blue、缺口=red;复用 `.tile/.alloc/.medal/.badge/.chip`;新增 `.commit-chip`。全 Inter,无 serif。
**旧组件退役:** `UnitDetail.svelte`/`ProjectDetail.svelte`/`TaskMarket.svelte` 在新台稳定后逐步移除引用(community/projects drawer 改指新组件或下线)。

---

## 实现顺序(重建)

```
0  设计签字(本文)——你确认 schema 后才动 DB
1  迁移脚本:新表 DDL + 老→新数据迁移(幂等)→ 本地应用 + 校验行数
2  RPC 层:forge_* / work_seat / review_* (概念命名)
3  前端:CardBinder/MemberCard/Matcher(卡牌册)→ SlotBoard/ProjectSlotCard(槽板)→ ForgeQueue
4  路由接线 + 旧组件下线 + i18n + build + commit
```

## 待你签字的点
- **目标 schema(A–G)整体方向**对不对?尤其:① `project_slot` 统一固有槽+需求槽;② `forge_request` 统一所有造/改卡审批;③ `work_commitment` 合并 stake_commitment+commitment_period。
- 旧表**保留不 drop**(留回滚窗口)可接受吗?
- 新路由 `/officer/chapter|wg/[unitId]` + `/admin/forge-queue` 命名 OK 吗?
