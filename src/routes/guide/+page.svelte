<script lang="ts">
  // R3 — the reference manual, rewritten to the new model (Person · Project ·
  // Need · Task · Skill · STR) and the surfaces (People · Projects · My).
  // Issue #15: localized (en/zh/ja/fr) — content lives in GUIDE keyed by locale,
  // so the whole manual translates with the language switch. Falls back to en.
  import { locale } from '$lib/i18n';

  type Card = { h: string; p: string };
  type Cta = { href: string; label: string };
  type PageRow = { href: string; label: string; desc: string };
  type Term = { dt: string; dd: string };
  type Guide = {
    title: string; lead: string;
    toc: { id: string; label: string }[];
    whatH: string; whatLead: string; cards: Card[];
    youH: string; youLead: string; youItems: string[]; youFoot: string;
    chapH: string; chapActs: string[]; chapCta: Cta;
    wgH: string; wgActs: string[]; wgCta: Cta;
    strH: string; strLead: string; flow: string[]; strBody: string; strCta: Cta;
    pagesH: string; pages: PageRow[];
    glossH: string; terms: Term[];
  };

  const GUIDE: Record<string, Guide> = {
    en: {
      title: 'How The Fin AI Community works',
      lead: `A shared, living record of the community's <strong>projects</strong> and
        <strong>people</strong> — the <em>coordination</em> layer: who's doing what, who's free, what's still
        unstaffed, what's due. Your draft and notes stay in their own tools (Overleaf, a repo, meeting notes)
        and link in here. Working groups run their projects in it; chapters keep their people in it;
        finished work settles into <strong>STR</strong> credit. In Phase 1, officers keep the record on
        behalf of members who don't log in yet.`,
      toc: [
        { id: 'what', label: 'What this is' }, { id: 'you', label: 'What you do' },
        { id: 'chapter', label: 'If you run a chapter' }, { id: 'wg', label: 'If you run a working group' },
        { id: 'str', label: 'How STR works' }, { id: 'pages', label: 'Your pages' }, { id: 'glossary', label: 'Glossary' }
      ],
      whatH: 'What this is', whatLead: 'Six things, and only six:',
      cards: [
        { h: 'Person', p: 'A researcher, with <strong>skills</strong> (at a level) and a monthly <strong>capacity</strong> (hours). Lives in a <strong>chapter</strong>.' },
        { h: 'Project', p: 'Work toward a publication, owned by a <strong>working group</strong>. Has a task board, a team, needs and milestones.' },
        { h: 'Need', p: 'What a project requires to form: a skill at a level, or a resource, with a capacity. Filled by <strong>matching</strong>.' },
        { h: 'Task', p: "A piece of work with an owner and a status — the living record of who's doing what, the part a shared doc always does worst." },
        { h: 'Skill', p: 'What someone can do, at <strong>Learning · Independent · Lead</strong>, backed by evidence from the record.' },
        { h: 'STR', p: 'The credit. Contribution <em>accrues</em>; a finished project <em>settles</em> it into spendable STR.' }
      ],
      youH: 'What you do', youLead: 'The org has two halves, and you steward one (or both):',
      youItems: [
        '<strong>A chapter</strong> holds <strong>people</strong> — you register them, keep their skills &amp; capacity current, and place them onto open work.',
        "<strong>A working group</strong> holds <strong>projects</strong> — you run each project's record, post what it needs, and split the credit when it ships."
      ],
      youFoot: 'Start from <strong>Home</strong>: it shows a short "what needs you" list and drops you into the right page.',
      chapH: 'If you run a chapter — you steward people',
      chapActs: [
        '<strong>Add your people.</strong> On <strong>People</strong>, "Add a person" (name + email). Then on their card, set their skills (one tap: Learning / Independent / Lead) and their monthly hours.',
        '<strong>Match them to open work.</strong> On People, "Match people to needs": pick a need, see ranked candidates with their <strong>spare capacity</strong> and why they fit, and <strong>Assign</strong> in place. The capacity bar turns red before it lets you over-commit anyone.',
        '<strong>Keep skills honest.</strong> As someone owns more tasks and ships projects, the system suggests a level raise — earned from the record, not self-rated.'
      ],
      chapCta: { href: '/people', label: 'Open People →' },
      wgH: 'If you run a working group — you steward projects',
      wgActs: [
        '<strong>Create or claim a project</strong> (free, no bond). Its first-author seat starts open.',
        '<strong>Run its record.</strong> On the project, the <strong>task board</strong> leads — add tasks, set owners and status, keep coverage checklists. Link your draft (Overleaf), repo and dataset under <strong>Draft &amp; links</strong>, and keep notes under <strong>Meetings</strong>. This takes over the coordination your Google Doc did — the writing stays where you write it.',
        '<strong>Post what it needs.</strong> "Post a role" — a skill at a level, or a resource — and you\'ll see how many people qualify. Chapter officers match their people into it.',
        '<strong>Finish &amp; split.</strong> When the paper lands, mark it finished and split the credit; weights default to logged hours with a fairness check.'
      ],
      wgCta: { href: '/projects', label: 'Open Projects →' },
      strH: "How STR works (quiet until it's real)",
      strLead: '<strong>STR</strong> is the unit of credit. It stays out of the way of the daily record and shows up only where it matters:',
      flow: ['Contribute (hours / resources)', 'Accruing (locked)', 'Finish', 'Split', 'Settled (spendable)'],
      strBody: "Each month a person's committed hours and resources <strong>accrue</strong> STR into the project's pool (locked). Verified <strong>milestones</strong> (submitted, accepted, released) raise the payout. When the project is finished, the pool <strong>settles</strong>: each contributor is paid their share as spendable STR. You see it on <strong>My tasks</strong> (your wallet) and at settlement — nowhere else.",
      strCta: { href: '/wallet', label: 'See your wallet →' },
      pagesH: 'Your pages',
      pages: [
        { href: '/', label: 'Home', desc: 'what needs you right now.' },
        { href: '/projects', label: 'Projects', desc: "your group's projects & their living record." },
        { href: '/people', label: 'People', desc: 'the roster, skills & capacity, and the matching board.' },
        { href: '/my', label: 'My tasks', desc: 'every task you own, across all projects, plus your wallet.' },
        { href: '/community', label: 'Directory', desc: 'browse people, chapters, working groups & the skill catalog.' }
      ],
      glossH: 'Glossary',
      terms: [
        { dt: 'Person', dd: 'A researcher (in Phase 1, a card an officer manages).' },
        { dt: 'Chapter', dd: 'A unit that holds people.' },
        { dt: 'Working group', dd: 'A unit that holds projects.' },
        { dt: 'Need', dd: 'An open role on a project — a skill@level or a resource — filled by matching.' },
        { dt: 'Task', dd: 'A unit of work with an owner and a status.' },
        { dt: 'Skill level', dd: 'Learning · Independent · Lead, backed by evidence (tasks · shipped).' },
        { dt: 'Capacity', dd: 'How many hours a month a person can give.' },
        { dt: 'Assign', dd: 'Place a person onto a need.' },
        { dt: 'First author', dd: 'The project lead — itself a need, matched like any other.' },
        { dt: 'Milestone', dd: 'A verified outcome (submitted, accepted, released) that raises the payout.' },
        { dt: 'STR', dd: 'The credit. Accruing (locked) → Settled (spendable).' },
        { dt: 'Settle / Split', dd: "Pay out a finished project's pool by each contributor's share." }
      ]
    },

    zh: {
      title: 'The Fin AI 社区怎么运作',
      lead: `社区<strong>项目</strong>与<strong>成员</strong>的一份共享的、活的记录——它是<em>协同</em>层:谁在做什么、谁有空、
        还有哪些岗位没人、什么时候截稿。你的草稿和笔记留在各自的工具里(Overleaf、代码库、会议记录),在这里链接进来。
        工作组在这里跑自己的项目,分会在这里管自己的人;完成的工作结算成 <strong>STR</strong> 积分。
        第一阶段,由 officer 代替还没登录的成员维护这份记录。`,
      toc: [
        { id: 'what', label: '这是什么' }, { id: 'you', label: '你要做什么' },
        { id: 'chapter', label: '如果你管一个分会' }, { id: 'wg', label: '如果你管一个工作组' },
        { id: 'str', label: 'STR 怎么运作' }, { id: 'pages', label: '你的页面' }, { id: 'glossary', label: '术语表' }
      ],
      whatH: '这是什么', whatLead: '只有六样东西:',
      cards: [
        { h: '成员 Person', p: '一位研究者,带<strong>技能</strong>(分等级)和每月<strong>产能</strong>(小时)。归属于一个<strong>分会</strong>。' },
        { h: '项目 Project', p: '面向一篇论文的工作,归属于一个<strong>工作组</strong>。有任务板、团队、需求和里程碑。' },
        { h: '需求 Need', p: '项目组建所需要的:某等级的一项技能,或一种资源,带一个容量。通过<strong>匹配</strong>来填补。' },
        { h: '任务 Task', p: '一件有负责人和状态的工作——这份活的记录,正是共享文档最不擅长的部分。' },
        { h: '技能 Skill', p: '一个人能做什么,分 <strong>Learning · Independent · Lead</strong> 三级,有记录里的证据支撑。' },
        { h: 'STR', p: '积分。贡献会<em>累积</em>;项目完成后<em>结算</em>成可用的 STR。' }
      ],
      youH: '你要做什么', youLead: '组织有两半,你看管其中一半(或两半都管):',
      youItems: [
        '<strong>分会</strong>管<strong>人</strong>——你登记他们,保持他们的技能和产能为最新,并把他们安排到开放的工作上。',
        '<strong>工作组</strong>管<strong>项目</strong>——你维护每个项目的记录,发布它的需求,论文发表后拆分积分。'
      ],
      youFoot: '从<strong>主页</strong>开始:它会给出一份简短的"需要你处理"清单,并把你带到对应页面。',
      chapH: '如果你管一个分会——你看管人',
      chapActs: [
        '<strong>添加你的人。</strong>在<strong>成员</strong>页"添加成员"(姓名 + 邮箱)。然后在他们的卡片上设置技能(一键:Learning / Independent / Lead)和每月小时数。',
        '<strong>把他们匹配到开放工作。</strong>在成员页"把人匹配到需求":选一个需求,看到带<strong>剩余产能</strong>和匹配理由的候选人排序,就地<strong>指派</strong>。产能条会在你把人安排超额之前先变红。',
        '<strong>让技能名副其实。</strong>当一个人承担更多任务、发表更多项目,系统会建议升级——由记录赚得,而非自评。'
      ],
      chapCta: { href: '/people', label: '打开成员 →' },
      wgH: '如果你管一个工作组——你看管项目',
      wgActs: [
        '<strong>创建或认领一个项目</strong>(免费,无押金)。它的第一作者席位一开始是空的。',
        '<strong>维护它的记录。</strong>在项目里,<strong>任务板</strong>是主角——加任务、设负责人和状态、维护覆盖清单。把你的草稿(Overleaf)、代码库、数据集链接到<strong>Draft &amp; links</strong>下,会议记录放在<strong>Meetings</strong>下。这接管了你 Google Doc 承担的协同——写作仍然留在你写作的地方。',
        '<strong>发布它的需求。</strong>"发布岗位"——某等级的技能,或一种资源——你会看到有多少人符合。分会 officer 会把人匹配进来。',
        '<strong>完成并拆分。</strong>论文落地后,标记为完成并拆分积分;权重默认按记录的小时数,并带公平性检查。'
      ],
      wgCta: { href: '/projects', label: '打开项目 →' },
      strH: 'STR 怎么运作(在变真之前,保持安静)',
      strLead: '<strong>STR</strong> 是积分单位。它不打扰日常记录,只在关键处出现:',
      flow: ['贡献(小时 / 资源)', '累积中(锁定)', '完成', '拆分', '已结算(可用)'],
      strBody: '每个月,一个人承诺的小时和资源会把 STR <strong>累积</strong>进项目的池子里(锁定)。经核实的<strong>里程碑</strong>(已提交、已接收、已发布)会抬高支付额。项目完成后,池子<strong>结算</strong>:每位贡献者按份额拿到可用的 STR。你只在<strong>我的任务</strong>(你的钱包)和结算时看到它——别处都看不到。',
      strCta: { href: '/wallet', label: '查看你的钱包 →' },
      pagesH: '你的页面',
      pages: [
        { href: '/', label: '主页', desc: '现在需要你处理什么。' },
        { href: '/projects', label: '项目', desc: '你这组的项目及其活的记录。' },
        { href: '/people', label: '成员', desc: '名册、技能与产能,以及匹配板。' },
        { href: '/my', label: '我的任务', desc: '你负责的每一项任务(跨所有项目),外加你的钱包。' },
        { href: '/community', label: '目录', desc: '浏览成员、分会、工作组与技能目录。' }
      ],
      glossH: '术语表',
      terms: [
        { dt: '成员 Person', dd: '一位研究者(第一阶段为 officer 管理的一张卡)。' },
        { dt: '分会 Chapter', dd: '装人的单位。' },
        { dt: '工作组 Working group', dd: '装项目的单位。' },
        { dt: '需求 Need', dd: '项目上一个开放的岗位——某等级的技能或一种资源——通过匹配填补。' },
        { dt: '任务 Task', dd: '一件有负责人和状态的工作。' },
        { dt: '技能等级 Skill level', dd: 'Learning · Independent · Lead,有证据支撑(任务数 · 已发表)。' },
        { dt: '产能 Capacity', dd: '一个人每月能投入多少小时。' },
        { dt: '指派 Assign', dd: '把一个人安排到一个需求上。' },
        { dt: '第一作者 First author', dd: '项目负责人——它本身也是一个需求,像其他需求一样匹配。' },
        { dt: '里程碑 Milestone', dd: '一个经核实的成果(已提交、已接收、已发布),会抬高支付额。' },
        { dt: 'STR', dd: '积分。累积中(锁定)→ 已结算(可用)。' },
        { dt: '结算 / 拆分 Settle / Split', dd: '按每位贡献者的份额,支付一个已完成项目的池子。' }
      ]
    },

    ja: {
      title: 'The Fin AI コミュニティの仕組み',
      lead: `コミュニティの<strong>プロジェクト</strong>と<strong>メンバー</strong>の共有された生きた記録——<em>調整</em>のレイヤーです:
        誰が何をしているか、誰が空いているか、まだ埋まっていない枠、締め切り。原稿やメモはそれぞれのツール(Overleaf、リポジトリ、議事録)に置き、ここにリンクします。
        ワーキンググループはここでプロジェクトを回し、チャプターはここでメンバーを管理します。完了した仕事は <strong>STR</strong> クレジットに精算されます。
        フェーズ1では、まだログインしないメンバーに代わって officer が記録を維持します。`,
      toc: [
        { id: 'what', label: 'これは何か' }, { id: 'you', label: 'あなたがすること' },
        { id: 'chapter', label: 'チャプターを運営するなら' }, { id: 'wg', label: 'ワーキンググループを運営するなら' },
        { id: 'str', label: 'STR の仕組み' }, { id: 'pages', label: 'あなたのページ' }, { id: 'glossary', label: '用語集' }
      ],
      whatH: 'これは何か', whatLead: '6つだけ、それ以上はありません:',
      cards: [
        { h: 'メンバー Person', p: '研究者。<strong>スキル</strong>(レベル付き)と月間<strong>稼働</strong>(時間)を持ちます。<strong>チャプター</strong>に所属します。' },
        { h: 'プロジェクト Project', p: '出版に向けた仕事で、<strong>ワーキンググループ</strong>が所有します。タスクボード、チーム、ニーズ、マイルストーンを持ちます。' },
        { h: 'ニーズ Need', p: 'プロジェクト成立に必要なもの:あるレベルのスキル、またはリソース(容量付き)。<strong>マッチング</strong>で埋めます。' },
        { h: 'タスク Task', p: '担当者とステータスを持つ一つの仕事——生きた記録であり、共有ドキュメントが最も苦手とする部分です。' },
        { h: 'スキル Skill', p: 'できることを <strong>Learning · Independent · Lead</strong> で表し、記録の根拠で裏付けます。' },
        { h: 'STR', p: 'クレジット。貢献は<em>累積</em>し、完了したプロジェクトでそれが使える STR に<em>精算</em>されます。' }
      ],
      youH: 'あなたがすること', youLead: '組織は二つの半分からなり、あなたはその一方(または両方)を担います:',
      youItems: [
        '<strong>チャプター</strong>は<strong>人</strong>を持ちます——登録し、スキルと稼働を最新に保ち、空いている仕事に配置します。',
        '<strong>ワーキンググループ</strong>は<strong>プロジェクト</strong>を持ちます——各プロジェクトの記録を回し、必要なものを掲示し、出版時にクレジットを分けます。'
      ],
      youFoot: '<strong>ホーム</strong>から始めましょう:短い「あなたに必要なこと」リストを表示し、適切なページへ案内します。',
      chapH: 'チャプターを運営するなら——あなたは人を担います',
      chapActs: [
        '<strong>メンバーを追加。</strong><strong>メンバー</strong>ページで「メンバーを追加」(氏名 + メール)。次にカードでスキル(ワンタップ:Learning / Independent / Lead)と月間時間を設定します。',
        '<strong>空いている仕事にマッチ。</strong>メンバーページの「人をニーズにマッチ」:ニーズを選び、<strong>余力</strong>と適合理由付きの候補者ランキングを見て、その場で<strong>アサイン</strong>。稼働バーは過剰割当の前に赤くなります。',
        '<strong>スキルを正直に保つ。</strong>より多くのタスクを担い、プロジェクトを出版すると、システムが昇格を提案します——自己評価ではなく記録から得られるものです。'
      ],
      chapCta: { href: '/people', label: 'メンバーを開く →' },
      wgH: 'ワーキンググループを運営するなら——あなたはプロジェクトを担います',
      wgActs: [
        '<strong>プロジェクトを作成または取得</strong>(無料、保証金なし)。第一著者の枠は最初は空いています。',
        '<strong>記録を回す。</strong>プロジェクトでは<strong>タスクボード</strong>が主役——タスク追加、担当とステータス設定、カバレッジのチェックリスト維持。原稿(Overleaf)・リポジトリ・データセットは<strong>Draft &amp; links</strong>に、メモは<strong>Meetings</strong>に。これが Google Doc の調整役を引き継ぎます——執筆は執筆ツールのままです。',
        '<strong>必要なものを掲示。</strong>「役割を掲示」——あるレベルのスキル、またはリソース——何人が該当するか分かります。チャプターの officer がメンバーをマッチします。',
        '<strong>完了して分割。</strong>論文が決まったら完了にしてクレジットを分割。重みは記録時間を既定とし、公平性チェック付きです。'
      ],
      wgCta: { href: '/projects', label: 'プロジェクトを開く →' },
      strH: 'STR の仕組み(現実になるまでは静かに)',
      strLead: '<strong>STR</strong> はクレジットの単位です。日々の記録の邪魔をせず、重要な場所にだけ現れます:',
      flow: ['貢献(時間 / リソース)', '累積中(ロック)', '完了', '分割', '精算済み(利用可)'],
      strBody: '毎月、各人の確約した時間とリソースが STR をプロジェクトのプールに<strong>累積</strong>します(ロック)。検証済みの<strong>マイルストーン</strong>(提出・受理・公開)は支払いを引き上げます。プロジェクト完了時、プールが<strong>精算</strong>され、各貢献者が持ち分を使える STR として受け取ります。<strong>マイタスク</strong>(あなたのウォレット)と精算時にだけ表示されます——それ以外には現れません。',
      strCta: { href: '/wallet', label: 'ウォレットを見る →' },
      pagesH: 'あなたのページ',
      pages: [
        { href: '/', label: 'ホーム', desc: '今あなたに必要なこと。' },
        { href: '/projects', label: 'プロジェクト', desc: 'あなたのグループのプロジェクトと生きた記録。' },
        { href: '/people', label: 'メンバー', desc: '名簿、スキルと稼働、そしてマッチングボード。' },
        { href: '/my', label: 'マイタスク', desc: '全プロジェクトであなたが担う全タスク、そしてウォレット。' },
        { href: '/community', label: 'ディレクトリ', desc: 'メンバー・チャプター・ワーキンググループ・スキルカタログを閲覧。' }
      ],
      glossH: '用語集',
      terms: [
        { dt: 'メンバー Person', dd: '研究者(フェーズ1では officer が管理するカード)。' },
        { dt: 'チャプター Chapter', dd: '人を持つ単位。' },
        { dt: 'ワーキンググループ Working group', dd: 'プロジェクトを持つ単位。' },
        { dt: 'ニーズ Need', dd: 'プロジェクト上の空き役割——スキル@レベル、またはリソース——マッチングで埋めます。' },
        { dt: 'タスク Task', dd: '担当者とステータスを持つ一単位の仕事。' },
        { dt: 'スキルレベル Skill level', dd: 'Learning · Independent · Lead、証拠(タスク数 · 公開数)で裏付け。' },
        { dt: '稼働 Capacity', dd: '一人が月にどれだけの時間を割けるか。' },
        { dt: 'アサイン Assign', dd: '人をニーズに配置すること。' },
        { dt: '第一著者 First author', dd: 'プロジェクトのリード——それ自体がニーズで、他と同様にマッチします。' },
        { dt: 'マイルストーン Milestone', dd: '支払いを引き上げる検証済みの成果(提出・受理・公開)。' },
        { dt: 'STR', dd: 'クレジット。累積中(ロック)→ 精算済み(利用可)。' },
        { dt: '精算 / 分割 Settle / Split', dd: '完了したプロジェクトのプールを各貢献者の持ち分で支払うこと。' }
      ]
    },

    fr: {
      title: 'Comment fonctionne la communauté The Fin AI',
      lead: `Un registre partagé et vivant des <strong>projets</strong> et des <strong>membres</strong> de la communauté —
        la couche de <em>coordination</em> : qui fait quoi, qui est disponible, ce qui reste à pourvoir, les échéances.
        Vos brouillons et notes restent dans leurs propres outils (Overleaf, un dépôt, des comptes rendus) et y sont liés.
        Les groupes de travail y mènent leurs projets ; les chapitres y gèrent leurs membres ; le travail terminé se règle
        en crédit <strong>STR</strong>. En phase 1, les officers tiennent le registre pour les membres qui ne se connectent pas encore.`,
      toc: [
        { id: 'what', label: "Ce que c'est" }, { id: 'you', label: 'Ce que vous faites' },
        { id: 'chapter', label: 'Si vous dirigez un chapitre' }, { id: 'wg', label: 'Si vous dirigez un groupe de travail' },
        { id: 'str', label: 'Comment marche STR' }, { id: 'pages', label: 'Vos pages' }, { id: 'glossary', label: 'Glossaire' }
      ],
      whatH: "Ce que c'est", whatLead: 'Six choses, et seulement six :',
      cards: [
        { h: 'Membre Person', p: 'Un chercheur, avec des <strong>compétences</strong> (à un niveau) et une <strong>capacité</strong> mensuelle (heures). Rattaché à un <strong>chapitre</strong>.' },
        { h: 'Projet Project', p: "Un travail vers une publication, détenu par un <strong>groupe de travail</strong>. Possède un tableau de tâches, une équipe, des besoins et des jalons." },
        { h: 'Besoin Need', p: "Ce qu'il faut pour former un projet : une compétence à un niveau, ou une ressource, avec une capacité. Pourvu par <strong>matching</strong>." },
        { h: 'Tâche Task', p: "Une unité de travail avec un responsable et un statut — le registre vivant, ce qu'un document partagé fait le plus mal." },
        { h: 'Compétence Skill', p: 'Ce que quelquun sait faire, en <strong>Learning · Independent · Lead</strong>, étayé par des preuves du registre.' },
        { h: 'STR', p: "Le crédit. La contribution <em>s'accumule</em> ; un projet terminé la <em>règle</em> en STR utilisable." }
      ],
      youH: 'Ce que vous faites', youLead: "L'organisation a deux moitiés, et vous en gérez une (ou les deux) :",
      youItems: [
        '<strong>Un chapitre</strong> détient des <strong>membres</strong> — vous les inscrivez, tenez à jour leurs compétences et capacité, et les placez sur le travail ouvert.',
        '<strong>Un groupe de travail</strong> détient des <strong>projets</strong> — vous tenez le registre de chaque projet, publiez ses besoins, et partagez le crédit à la publication.'
      ],
      youFoot: 'Commencez par <strong>Accueil</strong> : il affiche une courte liste « ce qui requiert votre attention » et vous mène à la bonne page.',
      chapH: 'Si vous dirigez un chapitre — vous gérez les membres',
      chapActs: [
        '<strong>Ajoutez vos membres.</strong> Sur <strong>Membres</strong>, « Ajouter une personne » (nom + e-mail). Puis sur sa fiche, définissez ses compétences (un tap : Learning / Independent / Lead) et ses heures mensuelles.',
        '<strong>Affectez-les au travail ouvert.</strong> Sur Membres, « Associer les personnes aux besoins » : choisissez un besoin, voyez les candidats classés avec leur <strong>capacité disponible</strong> et pourquoi ils conviennent, et <strong>Affectez</strong> sur place. La barre de capacité devient rouge avant tout surengagement.',
        '<strong>Gardez les compétences honnêtes.</strong> À mesure quune personne prend des tâches et publie des projets, le système suggère une montée de niveau — gagnée par le registre, non auto-évaluée.'
      ],
      chapCta: { href: '/people', label: 'Ouvrir Membres →' },
      wgH: 'Si vous dirigez un groupe de travail — vous gérez les projets',
      wgActs: [
        '<strong>Créez ou revendiquez un projet</strong> (gratuit, sans caution). Son siège de premier auteur est ouvert au départ.',
        "<strong>Tenez son registre.</strong> Sur le projet, le <strong>tableau de tâches</strong> mène — ajoutez des tâches, définissez responsables et statuts, tenez les listes de couverture. Liez votre brouillon (Overleaf), dépôt et jeu de données sous <strong>Draft &amp; links</strong>, et gardez les notes sous <strong>Meetings</strong>. Cela reprend la coordination de votre Google Doc — l'écriture reste là où vous écrivez.",
        "<strong>Publiez ses besoins.</strong> « Publier un rôle » — une compétence à un niveau, ou une ressource — et vous verrez combien de personnes qualifient. Les officers de chapitre y associent leurs membres.",
        '<strong>Terminez et partagez.</strong> À la parution, marquez le projet terminé et partagez le crédit ; les poids par défaut suivent les heures enregistrées avec un contrôle d\'équité.'
      ],
      wgCta: { href: '/projects', label: 'Ouvrir Projets →' },
      strH: "Comment marche STR (discret jusqu'à ce que ce soit réel)",
      strLead: "<strong>STR</strong> est l'unité de crédit. Il reste à l'écart du registre quotidien et n'apparaît que là où ça compte :",
      flow: ['Contribuer (heures / ressources)', 'En accumulation (bloqué)', 'Terminer', 'Partager', 'Réglé (disponible)'],
      strBody: "Chaque mois, les heures et ressources engagées d'une personne <strong>accumulent</strong> du STR dans la cagnotte du projet (bloqué). Les <strong>jalons</strong> vérifiés (soumis, accepté, publié) augmentent le versement. À la fin du projet, la cagnotte se <strong>règle</strong> : chaque contributeur reçoit sa part en STR utilisable. Vous le voyez sur <strong>Mes tâches</strong> (votre portefeuille) et au règlement — nulle part ailleurs.",
      strCta: { href: '/wallet', label: 'Voir votre portefeuille →' },
      pagesH: 'Vos pages',
      pages: [
        { href: '/', label: 'Accueil', desc: 'ce qui requiert votre attention maintenant.' },
        { href: '/projects', label: 'Projets', desc: 'les projets de votre groupe et leur registre vivant.' },
        { href: '/people', label: 'Membres', desc: 'le répertoire, les compétences et la capacité, et le tableau de matching.' },
        { href: '/my', label: 'Mes tâches', desc: 'chaque tâche dont vous êtes responsable, tous projets confondus, plus votre portefeuille.' },
        { href: '/community', label: 'Annuaire', desc: 'parcourir membres, chapitres, groupes de travail et le catalogue de compétences.' }
      ],
      glossH: 'Glossaire',
      terms: [
        { dt: 'Membre Person', dd: 'Un chercheur (en phase 1, une fiche gérée par un officer).' },
        { dt: 'Chapitre Chapter', dd: 'Une unité qui détient des membres.' },
        { dt: 'Groupe de travail Working group', dd: 'Une unité qui détient des projets.' },
        { dt: 'Besoin Need', dd: 'Un rôle ouvert sur un projet — une compétence@niveau ou une ressource — pourvu par matching.' },
        { dt: 'Tâche Task', dd: 'Une unité de travail avec un responsable et un statut.' },
        { dt: 'Niveau de compétence Skill level', dd: 'Learning · Independent · Lead, étayé par des preuves (tâches · publiés).' },
        { dt: 'Capacité Capacity', dd: "Combien d'heures par mois une personne peut donner." },
        { dt: 'Affecter Assign', dd: 'Placer une personne sur un besoin.' },
        { dt: 'Premier auteur First author', dd: 'Le lead du projet — lui-même un besoin, associé comme les autres.' },
        { dt: 'Jalon Milestone', dd: 'Un résultat vérifié (soumis, accepté, publié) qui augmente le versement.' },
        { dt: 'STR', dd: 'Le crédit. En accumulation (bloqué) → Réglé (disponible).' },
        { dt: 'Régler / Partager Settle / Split', dd: "Verser la cagnotte d'un projet terminé selon la part de chaque contributeur." }
      ]
    }
  };

  const g = $derived(GUIDE[$locale] ?? GUIDE.en);
</script>

<svelte:head><title>Guide · The Fin AI</title></svelte:head>

<div class="stack guide">
  <header>
    <h1>{g.title}</h1>
    <p class="lead">{@html g.lead}</p>
  </header>

  <nav class="toc">{#each g.toc as s}<a href={`#${s.id}`}>{s.label}</a>{/each}</nav>

  <section class="card" id="what">
    <h2>{g.whatH}</h2>
    <p>{g.whatLead}</p>
    <div class="grid3">
      {#each g.cards as c}
        <div class="mc"><div class="mh">{c.h}</div><p>{@html c.p}</p></div>
      {/each}
    </div>
  </section>

  <section class="card" id="you">
    <h2>{g.youH}</h2>
    <p>{g.youLead}</p>
    <ul class="bul">{#each g.youItems as it}<li>{@html it}</li>{/each}</ul>
    <p>{@html g.youFoot}</p>
  </section>

  <section class="card" id="chapter">
    <h2>{g.chapH}</h2>
    <ol class="acts">{#each g.chapActs as a}<li>{@html a}</li>{/each}</ol>
    <a class="cbtn" href={g.chapCta.href}>{g.chapCta.label}</a>
  </section>

  <section class="card" id="wg">
    <h2>{g.wgH}</h2>
    <ol class="acts">{#each g.wgActs as a}<li>{@html a}</li>{/each}</ol>
    <a class="cbtn" href={g.wgCta.href}>{g.wgCta.label}</a>
  </section>

  <section class="card" id="str">
    <h2>{g.strH}</h2>
    <p>{@html g.strLead}</p>
    <div class="flow">
      {#each g.flow as step, i}
        <span class="step">{step}</span>{#if i < g.flow.length - 1}<span class="arr">→</span>{/if}
      {/each}
    </div>
    <p style="margin-top:.6rem;">{@html g.strBody}</p>
    <a class="ilink" href={g.strCta.href}>{g.strCta.label}</a>
  </section>

  <section class="card" id="pages">
    <h2>{g.pagesH}</h2>
    <ul class="pages">
      {#each g.pages as p}<li><a href={p.href}>{p.label}</a> — {p.desc}</li>{/each}
    </ul>
  </section>

  <section class="card" id="glossary">
    <h2>{g.glossH}</h2>
    <dl class="gloss">
      {#each g.terms as tm}<dt>{tm.dt}</dt><dd>{tm.dd}</dd>{/each}
    </dl>
  </section>
</div>

<style>
  .guide { max-width: 860px; gap: 1rem; }
  .lead { margin-top: -.4rem; font-size: .95rem; line-height: 1.6; }
  .cbtn { align-self: flex-start; margin-top: .4rem; padding: .5rem .9rem; border-radius: var(--r-sm); background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; display: inline-block; }
  .toc { display: flex; flex-wrap: wrap; gap: .4rem .9rem; padding: .7rem .9rem; border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card); }
  .toc a { font-size: .85rem; color: var(--muted); text-decoration: none; }
  .toc a:hover { color: var(--accent); }
  section.card { padding: 1.1rem 1.2rem; }
  section h2 { margin: 0 0 .4rem; }
  section p, section li { line-height: 1.6; }
  .acts { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .55rem; }
  .bul { margin: .3rem 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .4rem; }
  .grid3 { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .7rem; margin-top: .5rem; }
  .mc { border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card-2); padding: .7rem .8rem; }
  .mh { font-size: .72rem; letter-spacing: .05em; text-transform: uppercase; color: var(--accent); font-weight: 700; }
  .mc p { margin: .3rem 0 0; font-size: .88rem; }
  .flow { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem; margin-top: .5rem; }
  .step { font-size: .8rem; padding: .3rem .6rem; border: 1px solid var(--border); border-radius: var(--r-full); background: var(--card-2); color: var(--text); }
  .arr { color: var(--muted); }
  .pages { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .5rem; }
  .pages a { font-weight: 600; }
  .ilink { color: var(--accent); text-decoration: none; font-size: .9rem; }
  .ilink:hover { text-decoration: underline; }
  .gloss { margin: 0; display: grid; grid-template-columns: max-content 1fr; gap: .4rem 1rem; }
  .gloss dt { font-weight: 600; color: var(--text); }
  .gloss dd { margin: 0; color: var(--muted); font-size: .9rem; }
  @media (max-width: 560px) { .gloss { grid-template-columns: 1fr; gap: .1rem .5rem; } .gloss dd { margin-bottom: .4rem; } }
</style>
