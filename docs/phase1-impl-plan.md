# Phase 1 实现计划

> 配套 `docs/phase1-concept.md`(概念定稿)。本文是**写码路线图**:基于对现有 SQL+前端的全量审查,
> 结论是 **Phase 1 后端已存在约 90%,前端已存在大部分** —— 工作以**组装 + 补匹配器 + 重构成两个 officer 操作台**为主,不是重写。

## 已确认的架构决策(2026-06-02)

| # | 决策 | 选择 |
|---|---|---|
| 1 | 容量(月度工时/资源额度) | **加数字 `monthly_quota` 列**(不再只靠自由文本 capacity 软检查) |
| 2 | officer 推人/声明承诺提交方式 | **逐项即时**(沿用 set_labor_commitment / assign_member,立即生效) |
| 3 | 认领项目卡机制 | **复用 `attach_project_to_unit`**(org_unit_id 为空的项目挂到我 WG = 认领) |
| 4 | 发需求是否走审 | **保持直插**(open_need 直接插入,Phase 1 求快、officer 互信) |
| 5 | 署名按需求类型(资源→通讯/末位候选) | **后置到 Settle 阶段**(现有 is_author/author_order 已够,Phase 1 不动) |

---

## 现状对账(审查结论)

**后端已存在、直接复用:**
- 铸成员卡:`forge_card(p_full_name,p_email,p_unit,p_affiliation,p_items)`(email 唯一,phase1_forge_once)
- 铸徽章:`mint_skillcard_batch(p_member,p_items)` → `skillcard_request`(submitted)→ approvals 审
- 铸资源:`resource` 直写(scope member/community,holder_member_id)→ approval 队列
- 认领:`attach_project_to_unit(p_project,p_unit)` / `detach_project_from_unit`
- 发需求:`open_need`(contribution_kind seat/labor/resource,skill_id,min_guild_level,headcount,hours_per_month,project_role_id)
- 推人 Work:`assign_member(p_project,p_member,p_role)`(无 bond);`set_labor_commitment(p,sk,ym,hours,p_as)` / `set_resource_commitment(p,res,ym,qty,p_as)`
- 月度 nominal:`stater_commitment_period`(月铸,`approval` 越容量队列);`review_commitment_period(p_period,p_approve)`
- 铸成 Settle:`submit_settlement` / `approve_settlement`(is_author/author_order,gated `project_status.name='Finished'`)
- 审批台:`/admin/approvals` 已 5 队列(越容量/里程碑/资源/徽章/单元申请)
- 能力门控:`src/lib/profile.ts`→`src/lib/session.ts` 暴露 `member`/`capabilities`/`officerUnits`(unit.kind 区分 chapter vs working_group)

**关键缺口(要建):**
- ❌ 卡牌册的**容量条 + 承诺片 + 匹配器([+ 投入项目])** —— 概念 §9 的核心交互未建
- ❌ WG 槽板:`UnitDetail` 的 WG 分支目前**只有 attach/detach**,无座位图/发需求/铸成入口(那些在 ProjectDetail)
- ⚠️ `resource` 无 `monthly_quota` 数字列(决策 #1 要加)
- ⚠️ ProjectDetail / TaskMarket 的 `p_as` 写死 null(act-as 仅在 UnitDetail 卡抽屉生效)

---

## Step 0 · Schema 迁移:`monthly_quota`(决策 #1)

新建 `supabase/migrations/<ts>_resource_monthly_quota.sql`:
1. `alter table resource add column monthly_quota numeric;`
2. 回填:`update resource set monthly_quota = _capacity_num(capacity) where monthly_quota is null;`
3. 改容量检查函数优先用数字列:
   - `resource_capacity_num(res)` → `coalesce(monthly_quota, _capacity_num(capacity))`
   - `member_labor_cap(p_member)` → `max(coalesce(monthly_quota,_capacity_num(capacity)))` over Labor 资源
4. `capacity` 文本列保留(显示/单位用),`monthly_quota` 为权威数字。
5. 应用到 live DB 后验证(本地 admin 连接,**不提交任何密码/密钥**)。

> 前端铸资源表单加一个"每月额度"数字输入写 `monthly_quota`;容量条按 `monthly_quota` 算占用比例。

---

## Step 1 · Chapter officer 卡牌册(主战场)

**文件:** `src/lib/UnitDetail.svelte`(chapter 分支)+ `src/lib/CardDrawer.svelte` 内容 + 新增 commit-chip 样式(`src/app.css`)。

1. **卡列表 → 折叠册**:每张 `kind='card'` 成员一行 = 头像 + 名字 + 徽章(Medal sm)+ **容量条**(复用 `.alloc`,liquid=已承诺/bonded=余量,按 `monthly_quota` 算)+ "坐了 N 个槽"。点击展开抽屉。
2. **展开卡抽屉**新增:
   - **承诺片列表**:每条 `项目名 · 40h · [改]`,左侧细条表占容量比(`.chip`+`.bar`)。数据来自该卡的 `stater_project_stake_commitment` + 本月 `stater_commitment_period`。
   - **容量条旁 [+ 投入项目] = 匹配器**(新组件,建议 `src/lib/Matcher.svelte`):
     - 加载**开着的 open_need**(复用 `TaskMarket` 的 need 加载 + `qualifiesFor`/`min_guild_level` 逻辑)
     - 三层筛:① 相位够格(`certified_level` ≥ `min_guild_level`)② 还有缺口(headcount/hours 未满)③ 资源对得上(该卡托管对应 resource_type → 高亮)
     - 不够格**显示但灰掉 + 标原因**(`opacity:.45;filter:grayscale(1)`),够格高亮(`var(--ring)`),默认按紧急度(缺口大/近 deadline)排序
     - 选中 + 填工时/数量 → 即时 `set_labor_commitment` / `set_resource_commitment`(`p_as`=卡)或 seat 类走 `assign_member`
3. **铸成员卡 / 铸徽章 / 铸资源**:已存在,保留;铸资源表单加 `monthly_quota` 输入。

## Step 2 · WG officer 槽板

**文件:** `src/lib/UnitDetail.svelte`(working_group 分支),必要时抽 `src/lib/SlotBoard.svelte`。

1. **认领区**:列 `org_unit_id is null` 的待领项目 → [认领] = `attach_project_to_unit(project, myWG)`;并列我 WG 已认领项目,按状态分组(未发需求 / 已开缺口缺N / 已满 / 待铸成 Finished)。
2. **每张项目卡**:
   - 座位图:Leader(`can_manage` 的 project_member 座位)+ 已坐成员
   - 需求槽列表(现有 open_need)+ **[+ 发需求]**(`open_need` 直插,标类型 labor=teal / resource=gold)
   - 跳 `/projects/[id]` 走铸成 Settle(已建,不重复)

## Step 3 · approvals 接线

现有队列已覆盖徽章/资源/越容量,**Phase 1 基本零改**。仅核对:WG officer 发需求保持直插(无新队列);文案对齐"Forge/铸卡"措辞。

## Step 4 · 收尾

- i18n:所有新字符串加英文 key(markup `{$t('...')}`,逻辑 `get(t)('...')`)+ `src/lib/messages.ts` 补 zh(必要时 ja/fr)
- `cd /Users/huangjimin/thefin-community && npm run build` 通过
- `node /tmp/i18n_audit.mjs` 干净(忽略 `"{n} done"` 误报)
- commit + push(默认授权)

---

## 实现顺序

```
Step 0 monthly_quota 迁移(小,先做,解锁容量条)
Step 1 卡牌册 + 匹配器        ← 脚本起点,最大块
Step 2 WG 槽板(认领+发需求)
Step 3 approvals 核对(可能零改)
Step 4 i18n + build + commit
```

## 安全约束(贯穿)
- DB 密码 / service_role / Resend key **绝不提交**;`.env` 已 gitignore。
- 迁移本地 admin 应用,只提交 `.sql` 文件本身,不含连接串。
- 不触碰登录/凭据;直接读生产 PII 受限。
