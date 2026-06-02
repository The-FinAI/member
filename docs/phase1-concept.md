# Phase 1 概念定稿 — 卡牌化协作模型

> 设计灵感借自《密教模拟器》(Cultist Simulator) 的「一切皆卡 / 槽 / 动词」语法,
> 但用**人审**替代随机(RNG)。本文是 Phase 1 写码前的**唯一参照**,概念已冻结。
> 阶段目标:把**现实**搬进系统(reality-mirroring onboarding),不是开始全新运营。

---

## 0. Phase 1 边界(谁在系统里)

| 角色 | Phase 1 是否登录 | 在系统里是什么 |
|---|---|---|
| **admin** | ✅ 真人 | 顶层托管:批量预铸项目卡、铸 officer 卡、铸社区资源、审批枢纽 |
| **chapter officer** | ✅ 真人 | 人的托管人:铸成员卡、铸徽章/资源、推人进槽 |
| **WG officer** | ✅ 真人 | 项目的托管人:认领项目卡、发需求、(后期)铸成 |
| leader / 一作 | ❌ 不登录 | 只是被代管的**成员卡**,坐在项目的 Leader 槽里 |
| 普通成员 | ❌ 不登录 | 只是被代管的**成员卡**,由 chapter officer 操作 |

**Phase 1 的三件事(都"尽快",并行):铸卡 · 认领 · 匹配 → 让系统状态 == 现实。**

---

## 1. 卡的三种角色

| 角色 | 是什么 | 现实对应 | 组件 |
|---|---|---|---|
| **Agent 成员卡** | 行动者句柄,携带内禀相位 + 名下资源 | 一个人 | (person-card) |
| **Slot 项目槽卡** | 索求相位、容纳座位的容器 | 一个项目 | UnitDetail / ProjectDetail |
| **Credential 徽章** | 附着在成员卡上、抬升技艺的凭证 | 技能认证 | `Medal.svelte` |

成员卡**本身不携带任何工时/算力/资金**——它只是句柄。所有可承诺的东西都是外挂的资源卡。

---

## 2. 两个内禀相位(aspect)

| 相位 | 含义 | 来源(谁注入) | 色 |
|---|---|---|---|
| **技艺 access** | 「能不能进」——准入门槛 | officer 铸**徽章** | teal `--accent` |
| **信誉 authority** | 「有没有权」——权限/决策 | admin 铸**权限**;或**坐进项目权威槽** | gold `--warn` |

> authority 有两个来源:① admin 注的全局权限(manage_*/review_*);② 坐进某项目的 **Leader 槽或 WG 槽** = 获得对该项目的**局部** authority(可发需求)。

---

## 3. 资源 = 全托管的月度额度卡

```
资源卡 resource:
  holder_member_id  NOT NULL        ← 社区内的人,唯一负责人,唯一能进槽
  scope ∈ {member, community}       ← 决定能进哪类槽
  resource_type ∈ {time, compute, data, fund}
  monthly_quota                     ← 每月额度(flow,非 stock)
  (无 owner 字段;owner 可在社区外、不建模,只在 Forge 审批留痕"holder 已确认可用")
```

- **owner(真实归属)vs holder(社区内托管人)**:系统只认 holder。owner 可以是外部的人/机构,不必入会、不必有卡。
- **工时也是资源**:`resource_type = time`,默认 holder = 本人,但可托管给他人。
- **月度**:Work 消费当月额度,按月重置(默认不结转)。容量校验 = Σ(本月该卡所有进槽承诺) ≤ monthly_quota。
- **改 holder = 一次 Forge**(更新卡 → 走审)。

---

## 4. 三个动词(唯一会改变世界状态的操作)

> **Forge 注入相位 → Work 消费相位 → Settle 兑现 STR。**

| 动词 | 做什么 | 闸门 | 谁把关 | 节律 |
|---|---|---|---|---|
| **① Forge 铸卡** | 创建/更新卡,注入相位 | 信誉复核 | reviewer(人审) | 随时 |
| **② Work 进槽** | 行动者卡进已开缺口,承诺相位+资源 | 容量校验 | 系统自动(越容量才人审) | 月度 |
| **③ Settle 结算** | 仅项目卡**铸成**时,nominal→liquid | 完成确认 | reviewer(人审) | 事件 |

- **认领 Claim** = 特殊 Forge(把项目卡的 holder 设为该 officer)。本组内自助、**即时免审**。
- **Settle 没有独立动词权**,它寄生在「项目终局 Forge(铸成)」过审的副作用上。

---

## 5. STR 结算体系

```
Work 每月 → 铸 nominal STR(锁定,攒进项目池,不可支配)
项目卡铸成那一刻 → Settle 一次 → 池中 nominal 全部兑成 liquid,按贡献分发落账
项目没铸成 → 池里永远是 nominal,谁都拿不走
```

激励内核:**变现绑定项目成败**——你每月投入攒 nominal,能否兑现赌的是项目最终铸不铸得成。

---

## 6. Officer 分工(严格不交叉)

| | Chapter officer | WG officer |
|---|---|---|
| 托管 | **人**(成员卡) | **项目**(槽卡) |
| Forge | 成员卡、徽章、成员资源 | 认领、发需求、铸成 |
| 对应卡角色 | Agent | Slot |
| 操作台 | **卡牌册**(按人) | **槽板**(按项目) |
| 匹配器位置 | 供给方(出人) | 需求方(出缺口) |
| 权限相位(admin 注) | manage_members / review_skillcard | edit_any_project / manage_resources |

> 要徽章就回 chapter officer 走——**一种卡一个托管源**,WG officer 不碰人的 Forge。

---

## 7. 进槽 = 只推不拉 + 现实回填

- **WG 不能拉人**:WG officer 只能**发需求**(开缺口)。开缺口 = 常驻的「我要这种卡」接收授权。
- **Chapter officer 推人**:在卡牌册看到缺口 → 和成员线下谈好 → 把人推进缺口。
- **不是直接指派**:前提是成员已同意。Phase 1 默认"线下已沟通同意",推过去**直接生效**,成员侧无阻塞(成员不登录)。
- **闸门**:够格(相位)+ 够量(月度额度);**越容量/越权才进审批队列**(唯一阻塞路径)。

---

## 8. 项目槽卡的内部结构(三层槽)+ 学术署名

```
项目槽卡 X
├─ 【固有角色槽】admin 铸卡时自带
│   └─ Leader 槽 = 一作(合并,1 人,做主要工作) → first author
│
├─ 【WG 槽】认领产生 → WG officer 占住 → 与 leader 发需求平权
│
└─ 【需求槽】Leader 或 WG officer 发布,按贡献类型分两型:
    ├─ 工时/技艺类需求(teal) → 填进来 = 中间作者 co-author
    └─ 资源类需求(gold)      → 填进来 = 通讯 + last-author candidate
```

**署名是 Work 进槽的副产品,由「坐哪个槽 / 投哪类需求」决定,项目铸成时连同 STR 一起结算:**

| 贡献 | 进哪类槽 | 署名 |
|---|---|---|
| 主导、做主要工作 | Leader 槽 | 一作 first author |
| 工时/技艺(干活) | 工时类需求槽 | 中间作者 co-author |
| 资源(算力/数据/资金) | 资源类需求槽 | 通讯 + last-author candidate(候选池) |

---

## 9. 交互范式(非拖拽)

密教模拟器的「拖卡入槽」**不适合**我们(移动端/无障碍/审批留痕/批量录入),改成**显式选择 + 确认 + 留痕**:

- **Chapter officer 卡牌册**:折叠卡列表(一行=名字+容量条+坐了几个槽);展开某卡 → 容量条(复用 wallet `.alloc`)+ 承诺片列表(`项目 · 40h · [改]`);容量条旁 **[+ 投入项目]** = 匹配器入口;底部**批量提交走审**。
- **匹配器**(双向同一套规则:相位够格 + 还有缺口 + 资源对得上):
  - 从卡出发 → 列「够格且缺这张卡的项目」
  - 从槽出发 → 列「够格且能填这个缺口的卡」
  - 不够格的**显示但灰掉 + 标原因**(`opacity .45 + grayscale`),够格高亮(`var(--ring)`),默认按**紧急度**排序。
- **WG officer 槽板**:本组项目卡列表(按状态:未发需求/已开缺口缺N/已满/待铸成)+ 每张卡的座位图 + 需求槽 + 发需求/铸成。

---

## 10. 设计语言(沿用现有"暗色交易终端")

**零新色、零新字体。** 概念绑定已有 token:

```
技艺 access    → --accent (teal)
信誉 authority → --warn  (gold)
liquid STR     → --up   (green)
nominal/staked → --info (blue)   (已是 .alloc .bonded 色)
缺口/超容量    → --down (red)
徽章档位       → .medal tier-g/s/b (金银铜,已现成)
够格高亮       → var(--ring);  不够格 → opacity .45 + grayscale
```

复用:`.tile`/`.kpi`(指标)、`.hero`+`.alloc`(容量条)、`.medal`(徽章)、`.txn`(活动流)、`.timeline`(Forge 历史)、`.detail-nav`(分区)、`.badge`/`.status`(相位/缺口标签)、`.chip.toggle`(视图/筛选切换)、drawer(匹配器)。

**仅新增 2 个原子:① 承诺片 commit-chip(`.chip`+`.bar` 组合)② 匹配抽屉 matcher(现有 drawer + ring/disabled 视觉)。**

字体:全 Inter(**不加** serif),保持终端一致性。

---

## 11. Phase 1 上线脚本(reality-mirroring)

```
admin(已完成):  批量铸好空项目槽卡(含 Leader 槽预填 = 现实 leader)

① Chapter officer ──尽快──> 铸成员卡(create) + 补徽章/资源
② WG officer      ──尽快──> 认领本组项目卡(claim,即时) + 发布需求(forge,走审)
③ Chapter officer ──尽快──> 把"现实里已在项目里的人"推进对应槽(work,回填)

→ 三步做完,系统 == 现实,之后才谈正常运营(发新需求/推新人/铸成结算)。
```

**动作集:** create(成员卡)· claim(项目卡,即时)· forge(徽章/资源/需求,走审)· work(推人,够量即时/越容量审)· settle(铸成,阶段末期)。

---

## 12. Phase 1 页面清单

```
管理面(新建/重做):
  ① Chapter officer 卡牌册   铸成员卡 + 铸徽章/资源 + 推人进缺口     ← 重做现有 "My chapter"
  ② WG officer 槽板/UnitDetail 认领 + 发需求 + 铸成                  ← 基于 UnitDetail
  ③ admin                    铸 officer + 社区资源                  ← 现成,接线
  ④ approvals 审批队列        接 forge(徽章/资源/需求)+ 越容量 work  ← 现成,加请求类型

参与面(officer 个人身份,现成、激活):
  ⑤ portfolio 首页 / ⑥ wallet / ⑦ 公开卡页  —— officer 看自己那张卡(只读)

不做:普通成员登录、接受邀请、成员侧主动交互、立项 Forge(admin 已批量铸)。
```

**建议实现顺序:① 卡牌册(脚本起点,没有人后面都做不了)→ ② WG 槽板 → ③ approvals 接线。**
