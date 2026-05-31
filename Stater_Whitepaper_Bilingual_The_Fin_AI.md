# Stater White Paper / Stater 白皮书

**A Staking-Based Contribution, Reputation, Project, and Community Signal Economy**  
**一个基于质押的贡献、声誉、项目与社区信号经济系统**

**Version / 版本:** v0.1  
**Organization / 组织:** The Fin AI  
**Token Name / 代币名称:** Stater / 斯塔特  
**Symbol / 符号:** STR  
**Scope / 适用范围:** Internal contribution credit, project governance, skill endorsement, resource commitment, milestone incentives, signal staking, settlement, and community awards.  
**适用范围：** 内部贡献信用、项目治理、技能背书、资源承诺、里程碑激励、信号质押、贡献结算与社区评奖。

---

## 1. Abstract / 摘要

Stater is an internal contribution-credit economy designed for research, open-source AI collaboration, and community project governance. It is not a public cryptocurrency, not an investment asset, and not designed for external trading. Instead, it is a staking-based mechanism that converts contribution, commitment, endorsement, resource support, project milestones, and community judgment into auditable internal credit.

Stater 是一个面向科研协作、开源 AI 项目和社区治理的内部贡献信用经济系统。它不是公开交易型加密货币，也不是投资资产，不用于外部交易。它是一套基于质押的机制，将贡献、承诺、背书、资源支持、项目里程碑和社区判断转化为可审计的内部信用。

Core logic / 核心逻辑：

```text
Endorsement has a cost.       背书有成本。
Participation requires stake. 参与需要质押。
Leaders carry responsibility. Leader 承担责任。
Writing must be fulfilled.    写作承诺必须兑现。
Skill time is valued.         技能时间可以计价。
Resources are auditable.      资源贡献可以审计。
Milestones are verifiable.    项目成果可以验证。
Signals can be staked.        社区信号可以质押。
Settlement is reviewed.       结算必须审核。
Ledger is append-only.        总账只追加、可追溯。
```

---

## 2. Naming / 命名

The system uses **Stater** as the token name. The term comes from ancient coinage. The Lydian stater is commonly described as one of the earliest official coins in history. This name reflects standardization, scarcity, verification, community recognition, and settlement.

本系统使用 **Stater / 斯塔特** 作为代币名称。Stater 来源于古代钱币名称，Lydian Stater 通常被认为是世界上最早的官方铸币之一。该名称象征标准化、稀缺性、可验证性、共同体认可和结算能力。

Recommended identifiers / 推荐标识：

```text
Name: Stater
Chinese Name: 斯塔特
Symbol: STR
Unit: stater
Plural: staters
Decimals: 0
External Trading: Not supported
Cash Redemption: Not supported
```

---

## 3. System Positioning / 系统定位

Stater is an internal contribution economy. Its value exists inside the community governance system and comes from contribution, commitment, endorsement, project achievement, resource fulfillment, and collective judgment.

Stater 是内部贡献信用经济。它的价值存在于社区治理系统内部，来自真实贡献、可信承诺、技能背书、项目成果、资源兑现和社区共识。

Stater is used for / Stater 用于：

1. Skill endorsement / 技能背书；
2. Project initiation and joining / 项目发起与加入；
3. Leader responsibility staking / Leader 责任质押；
4. First-author writing commitment / 一作写作承诺；
5. Skill-time valuation / 技能时间计价；
6. Resource stake / 资源质押；
7. Milestone bonus / 里程碑奖励；
8. Project settlement / 项目结算；
9. Signal staking / 信号质押；
10. Project visibility and community awards / 项目曝光与社区评奖；
11. Governance grants and treasury management / 治理发放与金库管理；
12. Auditable ledger and dispute resolution / 总账审计与争议处理。

---

## 4. Design Goals / 设计目标

### 4.1 Prevent Free Endorsement Inflation / 防止免费背书注水

Traditional endorsement is free and therefore easily abused through reciprocal endorsement, friendship-based support, or empty skill claims. Stater requires endorsers to spend their own STR, making endorsement scarce and meaningful.

传统背书免费，因此容易出现互相背书、朋友刷分、无贡献背书和技能信用注水。Stater 要求背书者花费自己的 STR，因此背书具有稀缺性和信号价值。

### 4.2 Prevent Free-Riding in Projects / 防止项目挂名参与

Joining a project requires token stake, skill-time stake, or resource stake. Only verified contribution can participate in final settlement.

加入项目必须提供 token 质押、技能时间质押或资源质押。只有被确认的真实贡献才能参与最终结算。

### 4.3 Make Leader Responsibility Explicit / 明确 Leader 责任

Leaders must stake before initiating a project. For research or writing-heavy projects, leaders must also stake first-author writing time.

Leader 发起项目前必须先质押。对于研究型或写作型项目，Leader 还必须质押一作写作时间。

### 4.4 Make Resource Commitments Verifiable / 让资源承诺可验证

Members may commit GPU, data, API credits, expert time, annotation labor, or funding. These commitments are recorded as token-equivalent stake and must be verified before settlement.

成员可以承诺 GPU、数据、API 额度、专家时间、标注人力或资金预算。这些承诺记录为 token-equivalent stake，并在结算前验证。

### 4.5 Make Project Outcomes Measurable / 让项目成果可衡量

Projects have both status and milestones. Status shows where a project is. Milestones show what it has achieved.

项目既有阶段，也有里程碑。阶段说明项目当前在哪里，里程碑说明项目已经完成了什么。

### 4.6 Turn Community Judgment into Signal / 将社区判断转化为信号

Members can stake STR on project value, completion, acceptance, resource fulfillment, milestones, or awards. Signal stake affects visibility and award scoring, but does not buy authorship or project payout rights.

成员可以用 STR 对项目价值、完成情况、录用情况、资源兑现、里程碑或评奖进行质押。信号质押影响曝光和评奖信号，但不能购买署名权或项目分红权。

---

## 5. Core Principles / 核心原则

| Principle | English | 中文 |
|---|---|---|
| Scarcity | STR is not infinite. Actions require cost or stake. | STR 不是无限积分，关键行为需要成本或质押。 |
| Conservation | Real token movement is recorded in the ledger. | 所有真实 token 流动进入总账。 |
| Auditability | Every mint, transfer, stake, payout, slash, and refund is traceable. | 每次铸造、转账、质押、分红、扣罚和退款都可追溯。 |
| Contribution First | Verified contribution is the basis of settlement. | 真实贡献是结算基础。 |
| Authorship Responsibility | Authorship must match verified contribution. | 署名必须匹配真实贡献。 |
| Signal Boundary | Signal stake does not grant project rights. | 信号质押不赋予项目权利。 |

---

## 6. Token Issuance / 发行设计

```text
Token Name: Stater
Symbol: STR
Decimals: 0
Initial Supply: 100,000 STR
Initial Recipient: Treasury
External Trading: Not supported
Cash Redemption: Not supported
```

Initial mint / 初始铸造：

```text
mint -> treasury: 100,000 STR
```

Stater uses integer units because it represents contribution and governance credit rather than a high-frequency trading asset.

Stater 采用整数单位，因为它代表贡献和治理信用，而不是高频交易资产。

---

## 7. Account System / 账户体系

### 7.1 Member Wallet / 成员钱包

Each member has one wallet.

每个成员拥有一个钱包。

Uses / 用途：

```text
Join project staking
Skill endorsement
Signal staking
Receiving project payout
Receiving welcome grant
Receiving allowance
Receiving governance grant
Receiving endorsement
```

### 7.2 Project Escrow / 项目托管账户

Each project has one escrow account.

每个项目拥有一个托管账户。

Receives / 接收：

```text
Leader initiation stake
Member join stake
Forfeited stake
Finish bonus
Milestone bonus
Project-specific grant
```

After approved settlement, project escrow is distributed according to final payout weights.

项目结算审核通过后，project escrow 按最终分红权重分配。

### 7.3 Market Escrow / 市场托管账户

Each signal market has one market escrow.

每个信号市场拥有一个市场托管账户。

Receives / 接收：

```text
Project signal stake
Outcome stake
Commitment fulfillment stake
Award signal stake
Risk stake
```

Market escrow is separate from project escrow and does not affect authorship or project payout.

Market escrow 与 project escrow 分离，不影响署名或项目分红。

### 7.4 Treasury / 社区金库

Treasury funds system-level issuance and receives fees or penalties.

Treasury 用于系统级发放，并接收费用和扣罚。

Uses / 用途：

```text
Welcome grant
Monthly allowance
Finish bonus
Milestone bonus
Governance grant
Award grant
Market fee collection
Slash collection
Emergency reserve
```

---

## 8. Ledger / 总账

All real STR movement is recorded in an append-only `token_ledger`.

所有真实 STR 流动都写入只追加的 `token_ledger`。

Ledger entry types / 总账类型：

```text
mint
transfer
stake
endorse
grant
allowance
finish_bonus
milestone_bonus
payout
refund
slash
burn
market_fee
```

Balance is computed from ledger entries rather than manually edited.

余额由总账实时计算，不直接手工修改。

```text
balance(account) =
sum(incoming ledger entries) - sum(outgoing ledger entries)
```

---

## 9. Skill Taxonomy / 技能树

Skills are used for endorsement, project matching, skill-time stake, contribution verification, and settlement.

技能用于背书、项目匹配、技能时间质押、贡献确认和结算。

### 9.1 Domain Skills / 领域技能

```text
Equities / Trading
Banking / Credit
Risk Management
Portfolio / Asset Management
Audit / Accounting / XBRL
RegTech / Compliance
ESG / Sustainable Finance
Macroeconomics
```

### 9.2 Language Skills / 语言技能

```text
Chinese
English
Spanish
French
German
Japanese
Korean
Arabic
Hindi
Portuguese
Russian
```

### 9.3 Research Skills / 科研技能

```text
Experiment Design
Benchmark Design
Evaluation & Metrics
Statistical Analysis
Literature Review
Paper Writing
Rebuttal / Review
```

`Paper Writing` is a special skill because first-author responsibility is linked to verified writing contribution.

`Paper Writing` 是特殊技能，因为一作责任与被验证的写作贡献绑定。

### 9.4 Engineering Skills / 工程技能

```text
Pretraining
Fine-tuning / SFT
RLHF / Alignment
Distributed Training / GPU
Inference & Serving
Agent / Tool-use / RAG
Multimodal
Data Engineering / Pipelines
Frontend / Backend Dev
```

### 9.5 Organization & Communication Skills / 组织与交流技能

```text
Project Management / Coordination
Meeting Facilitation / Hosting
Minutes / Record-keeping
Mentoring / Onboarding
Presentation / Public Speaking
Cross-team Collaboration
Community Building / Outreach
```

---

## 10. Resource Types / 资源类型

Resource stake allows members to join projects through resource contribution instead of liquid STR.

资源质押允许成员通过资源贡献加入项目，而不一定支付 liquid STR。

```text
Compute / GPU
Funding / Budget
API Credits
Dataset / Data Access
Annotation Labor
Software / License
Expert Time
Other
```

Resource contributions are recorded as token-equivalent stake, not immediately minted as liquid STR.

资源贡献记录为 token-equivalent stake，不立即铸造成可流通 STR。

---

## 11. Project Status / 项目阶段

| Order | Status | Active | Economic Meaning |
|---:|---|---|---|
| 10 | Proposal | Yes | Project proposal, recruiting, leader stake |
| 20 | Data Collecting | Yes | Data and resource contribution |
| 30 | Work in progress | Yes | Task execution, skill time, resources |
| 40 | Under review | Yes | Rebuttal, revision, review contribution |
| 50 | Finished | No | Triggers settlement and payout |
| 60 | Hold | No | Paused, no normal payout |

| 顺序 | 阶段 | 是否活跃 | 经济含义 |
|---:|---|---|---|
| 10 | Proposal / 提案 | 是 | 项目提案、招募、Leader 质押 |
| 20 | Data Collecting / 数据收集 | 是 | 数据和资源贡献 |
| 30 | Work in progress / 进行中 | 是 | 任务执行、技能时间、资源兑现 |
| 40 | Under review / 审稿中 | 是 | Rebuttal、修改、审稿贡献 |
| 50 | Finished / 已完成 | 否 | 触发结算和分红 |
| 60 | Hold / 搁置 | 否 | 暂停，不触发正常分红 |

---

## 12. Project Types / 项目类型

```text
Dataset & Benchmark
Model
Agent
Application
Trustworthy
```

Project type determines default skill requirements, resource needs, staking templates, milestone templates, settlement priorities, and award dimensions.

项目类型决定默认技能需求、资源需求、质押模板、里程碑模板、结算重点和评奖维度。

---

## 13. Project Milestones / 项目里程碑

Project Status shows where a project is. Project Milestone shows what a project has achieved.

Project Status 说明项目在哪个阶段。Project Milestone 说明项目已经达成了什么成果。

Milestone categories / 里程碑类别：

```text
submission
acceptance
release
open_source_impact
huggingface_impact
community_signal
benchmark_result
governance
```

### 13.1 Examples / 示例

Submission / 提交：

```text
arXiv uploaded
conference submission completed
journal submission completed
workshop submission completed
technical report published
```

Acceptance / 录用：

```text
paper accepted
top venue accepted
workshop paper accepted
demo accepted
challenge accepted
grant awarded
```

Release / 发布：

```text
dataset released
model released
demo launched
leaderboard released
API released
documentation released
blog post published
website launched
```

Open-source impact / 开源影响力：

```text
GitHub repository created
GitHub stars >= 10
GitHub stars >= 50
GitHub stars >= 100
GitHub stars >= 500
GitHub stars >= 1000
GitHub forks >= 20
external issues >= 5
external pull request received
```

Hugging Face impact / Hugging Face 影响力：

```text
Hugging Face model released
Hugging Face dataset released
Hugging Face Space launched
Hugging Face paper page created
Hugging Face paper daily top 10
Hugging Face paper daily top 5
Hugging Face paper daily top 3
Hugging Face paper daily top 1
Hugging Face downloads >= 100
Hugging Face downloads >= 1000
Hugging Face likes >= 50
```

Community signal / 社区信号：

```text
signal stake >= 100 STR
signal stake >= 500 STR
signal stake >= 1000 STR
unique stakers >= 10
unique stakers >= 30
positive signal ratio >= 70%
award signal top 5
```

Benchmark result / 基准结果：

```text
SOTA on internal benchmark
Top 3 on leaderboard
Outperforms baseline by 10%
Passes reliability threshold
Passes safety evaluation
Reduces hallucination rate by 20%
Achieves multilingual coverage target
```

Governance / 治理：

```text
Leader stake completed
First-author writing stake submitted
Minimum team formed
Required resources confirmed
Settlement meeting completed
Settlement approved
Payout completed
Dispute resolved
```

Milestone status / 里程碑状态：

```text
claimed
under_review
verified
rejected
expired
revoked
```

Only verified milestones can affect bonus, award score, visibility score, and market resolution.

只有 verified 里程碑可以影响奖励、评奖分、曝光分和市场结算。

---

## 14. How Members Earn STR / 如何获得 STR

### 14.1 Welcome Grant / 入会欢迎金

```text
welcome_grant = 100 STR
treasury -> member_wallet
```

### 14.2 Active Allowance / 活跃补贴

```text
monthly_allowance = 20 STR
condition = verified activity in last 30 days
```

Eligible activity / 有效活动：

```text
verified project contribution
settlement participation
review
task completion
resource verification
governance vote
community moderation
```

### 14.3 Project Payout / 项目分红

After a project is Finished and settlement is approved, project escrow is distributed according to approved weights.

项目进入 Finished 并通过结算审核后，project escrow 按 approved weights 分配。

### 14.4 Governance Grant / 治理发放

Authorized governance roles may mint to treasury or grant to members, projects, or award pools.

授权治理角色可以向 treasury 铸造，或向成员、项目、奖项池发放。

### 14.5 Signal Market Payout / 信号市场结算

Signal market winners may receive payout from market escrow.

信号市场预测正确者可从 market escrow 获得结算。

---

## 15. How Members Use STR / 如何使用 STR

### 15.1 Skill Endorsement / 技能背书

```text
endorse_min = 1 STR
endorser wallet -> recipient wallet
skill_id = endorsed skill
```

Recommended endorsement levels / 推荐背书等级：

```text
Normal endorsement: 1–5 STR
Strong endorsement: 10–20 STR
Exceptional endorsement: 50+ STR
```

### 15.2 Join Project / 加入项目

```text
join_stake = 20 STR
member wallet -> project escrow
```

Join stake is not burned. It enters the project escrow and is later redistributed through settlement.

加入质押不会立即销毁，而是进入 project escrow，并在结算时重新分配。

### 15.3 Leader Initiation Stake / Leader 发起质押

```text
leader_initiation_stake = 50 STR
leader wallet -> project escrow
```

### 15.4 Signal Stake / 信号质押

```text
signal_stake_min = 1 STR
market_creation_stake = 10 STR
market_fee_rate = 2%
```

Signal stake enters market escrow.

信号质押进入 market escrow。

---

## 16. Internal Project Staking / 项目内部质押

Project-internal staking determines membership, contribution records, authorship eligibility, and payout weight.

项目内部质押决定成员身份、贡献记录、署名资格和结算权重。

Types / 类型：

```text
Leader token stake
Leader first-author writing stake
Member token stake
Skill-time stake
Resource stake
```

### 16.1 Leader Token Stake / Leader token 质押

Leader stake represents responsibility for:

Leader stake 代表 Leader 对以下事项负责：

```text
project design
member recruiting
task coordination
meeting facilitation
resource coordination
writing integration
settlement meeting
settlement proposal
community review
```

If the project succeeds, leader stake enters the payout pool. If the leader abandons or abuses the project, leader stake can be slashed.

如果项目成功，Leader stake 进入分红池。如果 Leader 放弃或滥用项目，Leader stake 可被扣罚。

Recommended slash parameters / 推荐扣罚参数：

```text
leader_abandon_slash_rate = 50%
leader_misconduct_slash_rate = 100%
clean_cancel_refund_rate = 80%–100%
```

### 16.2 First-Author Writing Stake / 一作写作质押

For research, paper, report, benchmark, or white-paper projects, the Leader must stake first-author writing time.

对于研究、论文、报告、benchmark 或 white paper 项目，Leader 必须质押一作写作时间。

```text
default_first_author_writing_hours = 20
paper_writing_rate = 10 token-equivalent / hour
20 hours * 10 = 200 token-equivalent
```

This is not liquid STR. It is a token-equivalent commitment.

这不是 liquid STR，而是 token-equivalent commitment。

If Leader does not fulfill writing responsibility:

如果 Leader 没有履行写作责任：

```text
writing stake = forfeited
first-author claim = invalid or downgraded
payout weight adjusted
actual writer receives verified Paper Writing contribution
```

### 16.3 Skill-Time Stake / 技能时间质押

Members may commit verified hours for specific skills.

成员可以承诺某项技能的投入时间。

Examples / 示例：

```text
5 hours of Pretraining
8 hours of Benchmark Design
3 hours of Literature Review
10 hours of Data Engineering / Pipelines
4 hours of Presentation / Public Speaking
```

Status / 状态：

```text
pledged
accepted
verified
rewarded
rejected
forfeited
```

### 16.4 Resource Stake / 资源质押

Resource stake follows:

资源质押流程：

```text
pledged -> accepted -> verified -> rewarded
```

Only verified resource stake participates in settlement weight.

只有 verified resource stake 可以参与结算权重。

---

## 17. Skill Rate Policy / 技能计价策略

Recommended default rates, in token-equivalent per hour:

推荐默认计价，单位为 token-equivalent / hour：

```text
Paper Writing = 10
Experiment Design = 12
Benchmark Design = 12
Evaluation & Metrics = 12
Statistical Analysis = 12
Literature Review = 8
Rebuttal / Review = 10

Pretraining = 15
Fine-tuning / SFT = 12
RLHF / Alignment = 15
Distributed Training / GPU = 15
Inference & Serving = 12
Agent / Tool-use / RAG = 12
Multimodal = 12
Data Engineering / Pipelines = 12
Frontend / Backend Dev = 12

Project Management / Coordination = 10
Meeting Facilitation / Hosting = 8
Minutes / Record-keeping = 6
Mentoring / Onboarding = 8
Presentation / Public Speaking = 10
Cross-team Collaboration = 8
Community Building / Outreach = 10
```

---

## 18. Liquid STR vs Token-Equivalent Stake / Liquid STR 与 Token-Equivalent Stake

### 18.1 Liquid STR

Liquid STR can be spent, transferred internally, endorsed, staked, granted, or paid out.

Liquid STR 可以在系统内部花费、转移、背书、质押、发放或分红。

Used for / 用于：

```text
endorsement
join stake
leader stake
signal stake
market creation
grant
allowance
payout
```

### 18.2 Token-Equivalent Stake

Token-equivalent stake is a valuation of skill time, writing time, or resource contribution.

Token-equivalent stake 是技能时间、写作时间或资源贡献的估值。

It cannot be / 它不能：

```text
enter member wallet
change total supply
be spent
be transferred
be used for endorsement
be used for signal stake
```

It can be used for / 它可以用于：

```text
contribution records
settlement weight
authorship verification
resource fulfillment
award evaluation
milestone contribution
```

---

## 19. Project Settlement / 项目结算

Finished does not mean automatic payout.

Finished 不等于自动分红。

Process / 流程：

```text
Finished
-> Leader calls settlement meeting
-> contribution confirmation
-> settlement proposal
-> community review
-> approval
-> payout
-> closed
```

### 19.1 Settlement Meeting / 结算会议

Leader must convene the meeting to confirm:

Leader 必须召集会议确认：

```text
who actually contributed
what each member contributed
whether skill-time commitments were fulfilled
whether resources were delivered
whether Leader fulfilled first-author writing
who contributed to milestones
who qualifies for authorship
who abandoned commitments
final payout weights
disputes if any
```

### 19.2 Settlement Proposal / 结算提案

The proposal includes:

结算提案包括：

```text
project_id
submitted_by
meeting_notes
verified_token_stake
verified_skill_time
verified_resource_stake
first_author_writing_verification
milestone_contribution
authorship_list
final_payout_weight
dispute_notes
```

Leader organizes and submits. Leader does not unilaterally decide payout.

Leader 负责组织和提交，但不能单方面决定分红。

### 19.3 Community Review / 社区审核

```text
review_window = 72 hours
```

Status / 状态：

```text
submitted
under_review
approved
rejected
disputed
revised
paid
```

### 19.4 Payout Pool / 分红池

```text
Leader token stake
Member token stake
Forfeited stake
Finish bonus
Milestone bonus
Project grant
```

### 19.5 Payout Formula / 分红公式

```text
member_payout =
project_pool * member_final_weight / total_final_weight
```

Final weight / 最终权重：

```text
member_final_weight =
role_weight
+ verified_skill_time_weight
+ verified_resource_weight
+ writing_weight
+ milestone_contribution_weight
- penalty
```

Default role weights / 默认角色权重：

```text
Leader = 3
Co-lead = 2
Member = 1
```

---

## 20. Finish Bonus and Milestone Bonus / 完成奖励与里程碑奖励

### 20.1 Finish Bonus / 完成奖励

```text
finish_bonus_normal = 50 STR
finish_bonus ≈ 2x normal join_stake
```

### 20.2 Milestone Bonus / 里程碑奖励

Recommended / 推荐：

```text
arXiv uploaded = 20 STR
paper submitted = 30 STR
paper accepted = 100 STR
top venue accepted = 200 STR
workshop accepted = 50 STR
dataset released = 50 STR
model released = 50 STR
demo launched = 50 STR
GitHub stars >= 100 = 50 STR
GitHub stars >= 500 = 150 STR
HF paper daily top 10 = 30 STR
HF paper daily top 5 = 50 STR
HF paper daily top 1 = 100 STR
benchmark top 3 = 100 STR
SOTA result = 150 STR
```

Milestone bonus goes to project escrow, not directly to individuals.

里程碑奖励进入 project escrow，而不是直接发给个人。

---

## 21. Signal Stake / 信号质押

Signal stake is an external community signal mechanism.

Signal stake 是项目外部社区信号机制。

Types / 类型：

```text
Project Signal Stake
Outcome Stake
Commitment Fulfillment Stake
Award Signal Stake
Risk Stake
```

Signal stake does not grant / 信号质押不赋予：

```text
project membership
authorship
project payout right
internal project governance right
```

Signal stake affects / 信号质押影响：

```text
project visibility
community attention
award signal
confidence score
risk signal
prediction reputation
```

### 21.1 Market Payout / 市场结算

A simple pari-mutuel pool can be used:

可采用简单 pari-mutuel 池：

```text
winner_payout =
market_pool_after_fee * winner_stake / total_winning_stake
```

```text
market_fee_rate = 2%–5%
```

Market fee goes to treasury.

市场手续费进入 treasury。

---

## 22. Visibility and Awards / 曝光与评奖

### 22.1 Project Visibility Score / 项目曝光分

```text
visibility_score =
log(1 + counted_signal_stake)
+ 2 * log(1 + unique_stakers)
+ verified_milestone_score
+ positive_signal_bonus
- concentration_penalty
```

```text
visibility_counted_stake_per_user_cap = 100 STR
```

Stake above the cap can participate in market payout but does not increase visibility.

超过上限的 stake 可以参与市场结算，但不继续增加曝光度。

### 22.2 Award Score / 评奖分

```text
award_score =
verified_contribution_score
+ project_outcome_score
+ milestone_score
+ community_signal_score
```

Where / 其中：

```text
verified_contribution_score = settlement result
project_outcome_score = completion quality
milestone_score = verified milestones
community_signal_score = adjusted signal stake
```

---

## 23. Economic Parameters / 经济参数

Recommended default configuration / 推荐默认配置：

```text
initial_supply = 100000 STR

welcome_grant = 100 STR
monthly_allowance = 20 STR
allowance_condition = verified_activity_last_30_days

join_stake_small = 10 STR
join_stake_normal = 20 STR
join_stake_major = 40 STR
join_stake_flagship = 80 STR

leader_stake_small = 30 STR
leader_stake_normal = 50 STR
leader_stake_major = 100 STR
leader_stake_flagship = 200 STR

finish_bonus_small = 30 STR
finish_bonus_normal = 50 STR
finish_bonus_major = 80 STR
finish_bonus_flagship = 150 STR

endorse_min = 1 STR
market_creation_stake = 10 STR
signal_stake_min = 1 STR
market_fee_rate = 0.02

paper_writing_rate = 10 token-equivalent / hour
default_first_author_writing_hours = 20

review_window_hours = 72

visibility_counted_stake_per_user_cap = 100 STR
monthly_inflation_target = 0.03
treasury_reserve_min = 0.40
stake_lock_target_min = 0.30
stake_lock_target_max = 0.50
```

Project type defaults / 项目类型默认参数：

| Project Type | Join Stake | Leader Stake | Finish Bonus |
|---|---:|---:|---:|
| Dataset & Benchmark | 20 STR | 50 STR | 50 STR |
| Model | 30 STR | 80 STR | 80 STR |
| Agent | 20 STR | 50 STR | 50 STR |
| Application | 20 STR | 50 STR | 50 STR |
| Trustworthy | 20 STR | 60 STR | 60 STR |

---

## 24. Economic Stability / 经济稳定机制

Five key indicators / 五个核心指标：

```text
monthly inflation
treasury reserve ratio
stake lock ratio
project completion rate
signal concentration
```

### 24.1 Monthly Net Issuance / 月度净发行

```text
monthly_net_issuance =
welcome_grants
+ allowance
+ finish_bonus
+ milestone_bonus
+ governance_grants
- market_fees
- slashed_to_treasury
- burns
```

Target / 目标：

```text
monthly_net_issuance / circulating_supply <= 3%–5%
mature phase target = 1%–3%
```

### 24.2 Treasury Reserve Ratio / 金库储备率

```text
treasury_reserve_ratio =
treasury_balance / total_supply
```

Healthy target / 健康目标：

```text
treasury_reserve_ratio >= 40%
```

Adjustment / 调节：

```text
if treasury_reserve_ratio < 40%:
    reduce allowance by 50%
    reduce milestone bonus by 30%
    disable discretionary grants

if treasury_reserve_ratio < 25%:
    pause milestone bonus
    pause monthly allowance
    only allow payout from existing escrow
```

### 24.3 Stake Lock Ratio / 质押锁仓率

```text
stake_lock_ratio =
(project_escrow_balance + market_escrow_balance)
/
(member_wallet_balance + project_escrow_balance + market_escrow_balance)
```

Target / 目标：

```text
30% <= stake_lock_ratio <= 50%
```

Adjustment / 调节：

```text
if stake_lock_ratio < 20%:
    increase join stake or signal stake

if 20% <= stake_lock_ratio <= 50%:
    no adjustment

if 50% < stake_lock_ratio <= 70%:
    lower join stake or increase allowance

if stake_lock_ratio > 70%:
    liquidity danger mode
    reduce stake requirement
    increase active allowance
    encourage skill-time/resource stake
```

### 24.4 Project Completion Rate / 项目完成率

```text
project_completion_rate =
finished_projects / active_projects_started
```

Target / 目标：

```text
project_completion_rate >= 40%
```

### 24.5 Commitment Fulfillment Rate / 承诺兑现率

```text
commitment_fulfillment_rate =
verified_commitments / accepted_commitments
```

Target / 目标：

```text
commitment_fulfillment_rate >= 60%–70%
```

### 24.6 Signal Concentration / 信号集中度

Risk thresholds / 风险阈值：

```text
top_1_staker_share > 30%
top_3_staker_share > 60%
```

Actions / 调整：

```text
lower per-user visibility cap
increase unique staker weight
apply concentration penalty
separate payout stake from visibility stake
```

---

## 25. Treasury Inflows / 金库回流

Treasury should not only emit tokens; it should receive inflows.

金库不能只发放，也需要回流。

Sources / 来源：

```text
market_fee
slash penalty
cancelled project penalty
unclaimed rewards
expired inactive account reclaim
burn mechanism if needed
```

Endorsement fee is not recommended in the early stage because endorsement itself is already a transfer from one member to another.

早期不建议对背书收手续费，因为背书本身已经是成员间的信用转移。

---

## 26. Anti-Abuse Mechanisms / 防滥用机制

### 26.1 Anti-Reciprocal Endorsement / 防止互刷背书

```text
same endorser -> same recipient -> same skill frequency limit
unique endorser weighting
reciprocal endorsement detection
endorser reputation weighting
raw token amount log scaling
```

Skill score / 技能分：

```text
skill_score =
log(1 + received_endorse_tokens)
+ unique_endorser_score
+ endorser_reputation_score
+ project_verified_bonus
- reciprocal_penalty
```

### 26.2 Anti-Free-Riding / 防止挂名

Members without verified contribution should receive no authorship and no payout weight.

没有 verified contribution 的成员不应获得署名和分红权重。

### 26.3 Anti-Abandoned Projects / 防止 Leader 空开项目

Leader must stake, update, organize, and settle. Abandonment can trigger slash.

Leader 必须质押、更新、组织和结算。无故放弃可触发扣罚。

### 26.4 Anti-Fake Resource Commitment / 防止资源空头承诺

Resource stake does not count until verified.

资源质押在 verified 前不参与结算。

### 26.5 Anti-Milestone Gaming / 防止刷里程碑

```text
external metric must be snapshot-based
proof must be verifiable
same metric tier should not double-count
suspicious traffic or star farming can be rejected
admin can revoke milestone
```

### 26.6 Anti-Personal Attack in Signal Market / 防止信号市场攻击个人

Personal commitment markets must:

个人承诺市场必须：

```text
bind to project
bind to commitment
use objective criteria
notify target member
allow dispute
limit duplicate markets
slash malicious market creation stake
```

---

## 27. Database Objects / 数据库对象

### 27.1 Token

```text
token_account
token_ledger
token_policy
token_balance_view
skill_credit_view
```

### 27.2 Project Stake

```text
project_stake_commitment
project_skill_time_commitment
project_resource_commitment
project_settlement
project_settlement_item
project_payout
```

### 27.3 Milestone

```text
project_milestone_type
project_milestone
project_milestone_proof
project_milestone_bonus
```

### 27.4 Signal Market

```text
prediction_market
prediction_position
prediction_settlement
market_escrow_account
```

### 27.5 Governance

```text
governance_action
audit_log
dispute_case
policy_change_log
```

---

## 28. Core Table Schema / 核心表结构

### 28.1 token_account

```text
id
account_type: member | project_escrow | market_escrow | treasury
owner_member_id
project_id
market_id
created_at
```

### 28.2 token_ledger

```text
id
entry_type
from_account_id
to_account_id
amount
skill_id
project_id
market_id
milestone_id
settlement_id
reason
created_by
created_at
metadata
```

### 28.3 project_stake_commitment

```text
id
project_id
member_id
commitment_type:
  leader_initiation
  join_token
  first_author_writing
  skill_time
  resource
skill_id
resource_type
hours_committed
token_amount
token_equivalent
status:
  pledged
  accepted
  verified
  rewarded
  rejected
  forfeited
verified_by
verified_at
metadata
```

### 28.4 project_settlement

```text
id
project_id
submitted_by
status:
  draft
  submitted
  under_review
  approved
  rejected
  disputed
  paid
meeting_notes
review_window_ends_at
approved_by
approved_at
created_at
```

### 28.5 project_settlement_item

```text
id
settlement_id
member_id
role
verified_token_stake
verified_skill_time_equivalent
verified_resource_equivalent
writing_verified
milestone_contribution_score
final_payout_weight
is_author
author_order
notes
```

### 28.6 project_milestone

```text
id
project_id
milestone_type_id
title
description
status:
  claimed
  under_review
  verified
  rejected
  expired
  revoked
metric_name
metric_value
metric_unit
platform
target_value
achieved_at
claimed_by
verified_by
verified_at
proof_url
snapshot_url
metadata
```

### 28.7 prediction_market

```text
id
market_type:
  project_signal
  outcome
  commitment_fulfillment
  award_signal
  risk
project_id
target_member_id
target_commitment_id
target_milestone_id
created_by
question
outcome_type
status:
  draft
  open
  locked
  resolved
  disputed
  cancelled
resolution_criteria
resolution_source
open_at
lock_at
resolution_deadline
creation_stake
resolved_outcome
resolved_by
resolved_at
metadata
```

### 28.8 prediction_position

```text
id
market_id
member_id
outcome
stake_amount
status:
  active
  won
  lost
  refunded
created_at
```

---

## 29. Recommended RPCs / 推荐 RPC

### 29.1 Token RPC

```text
grant_welcome_stater()
mint_to_treasury()
grant_stater_to_member()
transfer_stater()
endorse_skill()
issue_monthly_allowance()
```

### 29.2 Project RPC

```text
create_project_with_leader_stake()
submit_first_author_writing_stake()
join_project_with_token_stake()
join_project_with_skill_time_stake()
join_project_with_resource_stake()
verify_skill_time_commitment()
verify_resource_commitment()
submit_settlement()
approve_settlement()
dispute_settlement()
execute_project_payout()
slash_leader_stake()
```

### 29.3 Milestone RPC

```text
claim_project_milestone()
submit_milestone_proof()
verify_milestone()
reject_milestone()
revoke_milestone()
issue_milestone_bonus_to_project_escrow()
```

### 29.4 Signal Market RPC

```text
create_signal_market()
stake_on_market()
lock_market()
resolve_market()
dispute_market_resolution()
execute_market_payout()
cancel_market()
refund_market()
```

---

## 30. Security Model / 安全模型

All STR write operations must go through SECURITY DEFINER RPCs. Frontend cannot directly write to the ledger.

所有 STR 写操作必须通过 SECURITY DEFINER RPC。前端不能直接写总账。

Each RPC must check:

每个 RPC 必须校验：

```text
caller permission
account existence
balance >= amount
project status
market status
settlement status
milestone verification status
no duplicate payout
RLS compliance
atomic ledger write
```

Critical operations must be atomic:

关键操作必须在单一 transaction 中完成：

```text
project payout
market payout
treasury grant
slash
refund
milestone bonus
settlement approval
project close
```

---

## 31. Admin Console / 管理后台

Admin → Stater Economy should show:

Admin → Stater Economy 应显示：

```text
treasury balance
total supply
circulating supply
monthly net issuance
treasury reserve ratio
stake lock ratio
project completion rate
commitment fulfillment rate
endorsement reciprocity rate
signal concentration
policy settings
audit logs
```

---

## 32. Health Dashboard / 经济健康面板

Monthly health report indicators:

月度健康报告指标：

| Metric | Healthy Range |
|---|---:|
| Treasury reserve ratio | > 40% |
| Stake lock ratio | 30%–50% |
| Monthly token inflation | < 3%–5% |
| Active member median balance | 50–200 STR |
| Project completion rate | > 40% |
| Abandoned project rate | < 20% |
| Commitment fulfillment rate | > 60%–70% |
| Endorsement reciprocity rate | < 25% |
| Signal concentration | top 1 < 30% |
| Payout dispute rate | < 15% |

---

## 33. Dynamic Policy Adjustment / 动态调参

### 33.1 If Inflation Is Too High / 如果通胀过高

```text
trigger: monthly_inflation > 5%

actions:
reduce allowance
reduce finish_bonus
reduce milestone_bonus
increase market_fee
tighten milestone verification
pause discretionary grants
```

### 33.2 If Liquidity Is Too Low / 如果流动性不足

```text
trigger:
stake_lock_ratio > 70%
median_member_balance < join_stake

actions:
reduce join_stake
increase active allowance
allow partial stake
encourage skill-time/resource stake
accelerate settlement
```

### 33.3 If Low-Quality Projects Increase / 如果低质量项目过多

```text
trigger: abandoned_project_rate > 20%

actions:
increase leader_stake
require stronger proposal
require minimum team before active
slash abandoned leader stake
reduce clean cancel refund
```

### 33.4 If Endorsement Farming Increases / 如果背书互刷严重

```text
trigger: reciprocal_endorsement_rate > 25%

actions:
increase reciprocal penalty
cap same-pair endorsement
increase unique endorser weight
lower raw token weight
```

### 33.5 If Visibility Is Manipulated / 如果曝光被操纵

```text
trigger:
top_1_staker_share > 30%
top_3_staker_share > 60%

actions:
lower per-user visibility cap
increase unique staker weight
apply concentration penalty
separate payout stake from visibility stake
```

---

## 34. Frontend Entry Points / 前端入口

### 34.1 Profile Page / 个人主页

```text
wallet balance
ledger history
skill credit
endorsements received
endorsements given
active project stakes
skill-time commitments
resource commitments
signal stake history
prediction accuracy
```

### 34.2 Member Directory / 成员目录

```text
skills
skill credit
project contribution
endorsement button
verified contributions
```

### 34.3 Project Detail Page / 项目详情页

```text
project type
project status
project milestones
required skills
required resources
project escrow balance
Leader stake
first-author writing stake
member stakes
skill-time commitments
resource commitments
signal stake
visibility score
award signal
settlement status
```

### 34.4 Settlement Page / 结算页面

```text
settlement proposal
verified contributions
authorship list
payout weights
dispute window
approval status
payout result
```

### 34.5 Signal Market Page / 信号市场页面

```text
project signal stake
outcome stake
commitment fulfillment stake
risk stake
award signal stake
market escrow
resolution rule
settlement result
```

### 34.6 Milestone Page / 里程碑页面

```text
claimed milestones
verified milestones
proof URL
snapshot
bonus status
award score impact
market resolution link
```

---

## 35. Rollout Strategy / 上线策略

### Phase 1: Cold Start / 冷启动期

Goal: make the community start using STR.

目标：让社区开始使用 STR。

```text
welcome_grant = 100
join_stake = 10–20
leader_stake = 30–50
finish_bonus = 50
allowance = 20
market_fee = 2%
```

Focus / 重点：

```text
skill endorsement
project joining
leader stake
basic settlement
```

### Phase 2: Growth / 增长期

Goal: prevent low-quality projects and endorsement farming.

目标：防止低质量项目和背书互刷。

Enable / 启用：

```text
milestone verification
first-author writing stake
market creation stake
reciprocal endorsement penalty
visibility cap
```

### Phase 3: Mature Governance / 成熟治理期

Goal: maintain low inflation, high contribution quality, and stable award governance.

目标：维持低通胀、高质量贡献和稳定评奖治理。

Enable / 启用：

```text
monthly inflation target = 1%–3%
stricter milestone bonus
award score formula
health dashboard
dynamic policy recommendation
```

---

## 36. Conclusion / 总结

Stater is a staking-based internal economy for contribution, reputation, project governance, milestone incentives, and community signal formation.

Stater 是一个基于质押的内部经济系统，用于贡献、声誉、项目治理、里程碑激励和社区信号形成。

Its core loops are:

它的核心闭环是：

```text
Project loop:
stake -> contribution -> settlement -> payout

项目闭环：
质押 -> 贡献 -> 结算 -> 分红

Reputation loop:
endorsement -> skill credit -> project opportunity -> verified contribution

声誉闭环：
背书 -> 技能信用 -> 项目机会 -> 真实贡献

Milestone loop:
milestone -> verification -> bonus -> award score

成果闭环：
里程碑 -> 验证 -> 奖励 -> 评奖分

Signal loop:
signal stake -> outcome resolution -> visibility / award / prediction reputation

信号闭环：
信号质押 -> 结果结算 -> 曝光 / 评奖 / 预测声誉

Governance loop:
ledger -> audit -> policy adjustment -> economic stability

治理闭环：
总账 -> 审计 -> 参数调节 -> 经济稳定
```

Stater is not a token for speculation.  
Stater is a coin of contribution, commitment, and trust.

Stater 不是投机代币。  
Stater 是贡献、承诺与信任之币。
