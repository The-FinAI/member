import type { Locale } from './i18n';

// Translation tables keyed by the English source string. English needs no table
// (it's the key). Add a key here in zh/ja/fr to translate it; omit to fall back
// to English. Roll out page by page — uncovered strings simply stay English.

type Table = Record<string, string>;

const zh: Table = {
  // ── nav / chrome ──
  'Projects': '项目',
  'Opportunities': '机会',
  'Guild': '行会',
  'Leaderboard': '排行榜',
  'Guide': '指南',
  'Admin': '管理',
  'Account': '账户',
  'Account menu': '账户菜单',
  'Profile & skills': '个人资料与技能',
  'Sign out': '退出登录',
  'Toggle theme': '切换主题',
  'Language': '语言',
  "You're signed in as {email}, but this email isn't linked to a membership. Access is invite-only — please ask an admin to invite you. Meanwhile you can":
    '你已用 {email} 登录,但该邮箱尚未关联会员身份。本社区仅限受邀加入——请联系管理员邀请你。在此期间你可以',
  'read how the community works →': '了解社区如何运作 →',

  // ── login ──
  'Sign in': '登录',
  "Membership is invite-only. Enter the email you were invited with — we'll send a magic link.":
    '会员仅限受邀。请输入你被邀请时使用的邮箱——我们会发送一个登录魔法链接。',
  'Send magic link': '发送魔法链接',
  'Sending…': '发送中…',
  'Check your inbox for the sign-in link.': '请查收邮箱中的登录链接。',
  'Supabase is not configured yet.': 'Supabase 尚未配置。',
  "This email isn't on the invite list. Ask a community admin to invite you first.":
    '该邮箱不在邀请名单中。请先让社区管理员邀请你。',

  // ── home / dashboard ──
  'Portfolio': '我的组合',
  'Your stake across the Stater research economy.': '你在 Stater 研究经济中的全部权益。',
  'Start a project': '发起项目',
  'STR balance': 'STR 余额',
  'Liquid STR — your spendable wallet balance. Used to post bonds and pay Guild exam fees.':
    '流动 STR——你钱包中可花费的余额,用于缴纳保证金和支付行会考试费。',
  'liquid, spendable': '流动,可花费',
  'Staked': '已质押',
  "Nominal STR you've minted into project pools — locked until each project settles, then it converts to liquid STR.":
    '你铸入各项目池的名义 STR——在项目结算前锁定,结算后转为流动 STR。',
  'bonded in projects': '锁定在项目中',
  'My projects': '我的项目',
  'projects joined': '已加入的项目',
  'Open needs': '开放需求',
  'across {n} projects': '来自 {n} 个项目',
  'My positions': '我的仓位',
  'Loading…': '加载中…',
  'No positions yet. Browse': '还没有仓位。浏览',
  'Open Opportunities': '开放机会',
  'to stake into a project, or': '以质押加入项目,或',
  'read how it works': '先了解运作方式',
  'first.': '。',
  'Project': '项目',
  'Role': '角色',
  'Status': '状态',
  'My applications': '我的申请',
  'No open orders.': '暂无进行中的申请。',
  'accepted · confirm to join →': '已接受 · 确认加入 →',

  // ── getting started checklist ──
  'Get started': '开始上手',
  '{done} of {total} done · new here?': '已完成 {done} / {total} · 新来的?',
  'Read how it works →': '了解运作方式 →',
  'Dismiss': '关闭',
  'done': '已完成',
  'Set up your profile': '完善个人资料',
  'List what you can bring — monthly labor and any resources.': '列出你能投入的——每月工时与各类资源。',
  'Open profile': '打开个人资料',
  'Find an opportunity': '寻找机会',
  'Browse open needs and apply to one that fits your skills.': '浏览开放需求,申请一个契合你技能的。',
  'Browse opportunities': '浏览机会',
  'Join a project': '加入项目',
  'Post the join bond and start declaring monthly contributions.': '缴纳加入保证金,开始申报每月贡献。',
  'Browse projects': '浏览项目',
  'Certify a skill': '认证技能',
  'Sit a Guild exam to earn a credential and raise your labor rate.': '参加行会考试,获取资质并提升你的工时单价。',
  'Visit the Guild': '前往行会',

  // ── wallet ──
  'Wallet': '钱包',
  'Your Stater (STR) balance and transaction history.': '你的 Stater(STR)余额与交易记录。',
  'No member record linked to this account yet.': '该账户尚未关联会员记录。',
  'Net worth': '净值',
  "Liquid balance plus nominal STR you've staked across projects. Staked STR isn't spendable until each project settles.":
    '流动余额加上你在各项目质押的名义 STR。已质押的 STR 在项目结算前不可花费。',
  'Liquid': '流动',
  'Liquid balance': '流动余额',
  'spendable now': '当前可花费',
  'Spendable STR in your wallet — used to post bonds and pay Guild exam fees.':
    '钱包中可花费的 STR——用于缴纳保证金和支付行会考试费。',
  'Nominal STR minted into project pools (your bond + declared work). Locked until each project settles, then converts to liquid.':
    '铸入项目池的名义 STR(你的保证金 + 申报的工作)。在项目结算前锁定,之后转为流动。',
  'Bonded ratio': '锁定比例',
  'of net worth at work': '净值中投入工作的占比',
  'Activity': '活动',
  'Earned by finishing projects; spent to join ({n}/join), stake, and endorse peers.':
    '通过完成项目赚取;用于加入({n}/次)、质押和为同伴背书。',
  'No transactions yet.': '暂无交易。'
};

const ja: Table = {
  // ── nav / chrome ──
  'Projects': 'プロジェクト',
  'Opportunities': '募集',
  'Guild': 'ギルド',
  'Leaderboard': 'ランキング',
  'Guide': 'ガイド',
  'Admin': '管理',
  'Account': 'アカウント',
  'Account menu': 'アカウントメニュー',
  'Profile & skills': 'プロフィールとスキル',
  'Sign out': 'ログアウト',
  'Toggle theme': 'テーマ切替',
  'Language': '言語',
  "You're signed in as {email}, but this email isn't linked to a membership. Access is invite-only — please ask an admin to invite you. Meanwhile you can":
    '{email} でログイン中ですが、このメールはメンバーに紐づいていません。参加は招待制です——管理者に招待を依頼してください。その間に',
  'read how the community works →': 'コミュニティの仕組みを読む →',

  // ── login ──
  'Sign in': 'サインイン',
  "Membership is invite-only. Enter the email you were invited with — we'll send a magic link.":
    'メンバーは招待制です。招待されたメールアドレスを入力してください——マジックリンクを送ります。',
  'Send magic link': 'マジックリンクを送信',
  'Sending…': '送信中…',
  'Check your inbox for the sign-in link.': '受信トレイのサインインリンクをご確認ください。',
  'Supabase is not configured yet.': 'Supabase はまだ設定されていません。',
  "This email isn't on the invite list. Ask a community admin to invite you first.":
    'このメールは招待リストにありません。まず管理者に招待を依頼してください。',

  // ── home / dashboard ──
  'Portfolio': 'ポートフォリオ',
  'Your stake across the Stater research economy.': 'Stater 研究エコノミーにおけるあなたの持ち分。',
  'Start a project': 'プロジェクトを始める',
  'STR balance': 'STR 残高',
  'Liquid STR — your spendable wallet balance. Used to post bonds and pay Guild exam fees.':
    '流動 STR——使用可能なウォレット残高。ボンドの拠出やギルド試験料の支払いに使います。',
  'liquid, spendable': '流動・使用可能',
  'Staked': 'ステーク済み',
  "Nominal STR you've minted into project pools — locked until each project settles, then it converts to liquid STR.":
    'プロジェクトプールに鋳造した名目 STR——各プロジェクトの精算までロックされ、その後 流動 STR に変換されます。',
  'bonded in projects': 'プロジェクトに拘束',
  'My projects': 'マイプロジェクト',
  'projects joined': '参加したプロジェクト',
  'Open needs': '募集中の需要',
  'across {n} projects': '{n} 件のプロジェクト',
  'My positions': 'マイポジション',
  'Loading…': '読み込み中…',
  'No positions yet. Browse': 'まだポジションがありません。',
  'Open Opportunities': '募集中の機会',
  'to stake into a project, or': 'を見てプロジェクトにステーク、または',
  'read how it works': '仕組みを読む',
  'first.': '。',
  'Project': 'プロジェクト',
  'Role': '役割',
  'Status': 'ステータス',
  'My applications': 'マイ応募',
  'No open orders.': '進行中の応募はありません。',
  'accepted · confirm to join →': '承認済み · 参加を確定 →',

  // ── getting started checklist ──
  'Get started': 'はじめる',
  '{done} of {total} done · new here?': '{total} 中 {done} 完了 · 初めてですか?',
  'Read how it works →': '仕組みを読む →',
  'Dismiss': '閉じる',
  'done': '完了',
  'Set up your profile': 'プロフィールを設定',
  'List what you can bring — monthly labor and any resources.': '提供できるものを記載——月あたりの稼働とリソース。',
  'Open profile': 'プロフィールを開く',
  'Find an opportunity': '機会を探す',
  'Browse open needs and apply to one that fits your skills.': '募集を見て、スキルに合うものに応募。',
  'Browse opportunities': '機会を見る',
  'Join a project': 'プロジェクトに参加',
  'Post the join bond and start declaring monthly contributions.': '参加ボンドを拠出し、月次の貢献を申告。',
  'Browse projects': 'プロジェクトを見る',
  'Certify a skill': 'スキルを認定',
  'Sit a Guild exam to earn a credential and raise your labor rate.': 'ギルド試験を受けて資格を取得し、稼働単価を上げる。',
  'Visit the Guild': 'ギルドへ',

  // ── wallet ──
  'Wallet': 'ウォレット',
  'Your Stater (STR) balance and transaction history.': 'あなたの Stater（STR）残高と取引履歴。',
  'No member record linked to this account yet.': 'このアカウントにはまだメンバー記録が紐づいていません。',
  'Net worth': '純資産',
  "Liquid balance plus nominal STR you've staked across projects. Staked STR isn't spendable until each project settles.":
    '流動残高と、各プロジェクトにステークした名目 STR の合計。ステークした STR は各プロジェクトの精算まで使えません。',
  'Liquid': '流動',
  'Liquid balance': '流動残高',
  'spendable now': '今すぐ使用可能',
  'Spendable STR in your wallet — used to post bonds and pay Guild exam fees.':
    'ウォレット内の使用可能な STR——ボンドの拠出やギルド試験料に使います。',
  'Nominal STR minted into project pools (your bond + declared work). Locked until each project settles, then converts to liquid.':
    'プロジェクトプールに鋳造した名目 STR（ボンド + 申告した作業）。各プロジェクトの精算までロックされ、その後 流動に変換されます。',
  'Bonded ratio': '拘束比率',
  'of net worth at work': '純資産のうち稼働中の割合',
  'Activity': 'アクティビティ',
  'Earned by finishing projects; spent to join ({n}/join), stake, and endorse peers.':
    'プロジェクトの完了で獲得；参加（{n}/回）、ステーク、仲間の推薦に使用。',
  'No transactions yet.': 'まだ取引はありません。'
};

const fr: Table = {
  // ── nav / chrome ──
  'Projects': 'Projets',
  'Opportunities': 'Opportunités',
  'Guild': 'Guilde',
  'Leaderboard': 'Classement',
  'Guide': 'Guide',
  'Admin': 'Admin',
  'Account': 'Compte',
  'Account menu': 'Menu du compte',
  'Profile & skills': 'Profil et compétences',
  'Sign out': 'Se déconnecter',
  'Toggle theme': 'Changer de thème',
  'Language': 'Langue',
  "You're signed in as {email}, but this email isn't linked to a membership. Access is invite-only — please ask an admin to invite you. Meanwhile you can":
    'Vous êtes connecté en tant que {email}, mais cet e-mail n’est lié à aucun membre. L’accès est sur invitation — demandez à un administrateur de vous inviter. En attendant, vous pouvez',
  'read how the community works →': 'découvrir le fonctionnement de la communauté →',

  // ── login ──
  'Sign in': 'Connexion',
  "Membership is invite-only. Enter the email you were invited with — we'll send a magic link.":
    'L’adhésion est sur invitation. Saisissez l’e-mail de votre invitation — nous enverrons un lien magique.',
  'Send magic link': 'Envoyer le lien magique',
  'Sending…': 'Envoi…',
  'Check your inbox for the sign-in link.': 'Vérifiez votre boîte de réception pour le lien de connexion.',
  'Supabase is not configured yet.': 'Supabase n’est pas encore configuré.',
  "This email isn't on the invite list. Ask a community admin to invite you first.":
    'Cet e-mail n’est pas sur la liste d’invitation. Demandez d’abord à un administrateur de vous inviter.',

  // ── home / dashboard ──
  'Portfolio': 'Portefeuille',
  'Your stake across the Stater research economy.': 'Votre participation dans l’économie de recherche Stater.',
  'Start a project': 'Lancer un projet',
  'STR balance': 'Solde STR',
  'Liquid STR — your spendable wallet balance. Used to post bonds and pay Guild exam fees.':
    'STR liquide — le solde dépensable de votre portefeuille. Sert à déposer des cautions et payer les examens de la Guilde.',
  'liquid, spendable': 'liquide, dépensable',
  'Staked': 'Engagé',
  "Nominal STR you've minted into project pools — locked until each project settles, then it converts to liquid STR.":
    'STR nominal frappé dans les pools de projet — bloqué jusqu’au règlement de chaque projet, puis converti en STR liquide.',
  'bonded in projects': 'immobilisé dans des projets',
  'My projects': 'Mes projets',
  'projects joined': 'projets rejoints',
  'Open needs': 'Besoins ouverts',
  'across {n} projects': 'sur {n} projets',
  'My positions': 'Mes positions',
  'Loading…': 'Chargement…',
  'No positions yet. Browse': 'Aucune position. Parcourez',
  'Open Opportunities': 'les opportunités ouvertes',
  'to stake into a project, or': 'pour vous engager dans un projet, ou',
  'read how it works': 'lisez le fonctionnement',
  'first.': ' d’abord.',
  'Project': 'Projet',
  'Role': 'Rôle',
  'Status': 'Statut',
  'My applications': 'Mes candidatures',
  'No open orders.': 'Aucune candidature en cours.',
  'accepted · confirm to join →': 'acceptée · confirmer pour rejoindre →',

  // ── getting started checklist ──
  'Get started': 'Commencer',
  '{done} of {total} done · new here?': '{done} sur {total} fait · nouveau ?',
  'Read how it works →': 'Lire le fonctionnement →',
  'Dismiss': 'Masquer',
  'done': 'fait',
  'Set up your profile': 'Configurez votre profil',
  'List what you can bring — monthly labor and any resources.': 'Indiquez ce que vous apportez — heures mensuelles et ressources.',
  'Open profile': 'Ouvrir le profil',
  'Find an opportunity': 'Trouver une opportunité',
  'Browse open needs and apply to one that fits your skills.': 'Parcourez les besoins et postulez à celui qui correspond à vos compétences.',
  'Browse opportunities': 'Voir les opportunités',
  'Join a project': 'Rejoindre un projet',
  'Post the join bond and start declaring monthly contributions.': 'Déposez la caution et déclarez vos contributions mensuelles.',
  'Browse projects': 'Voir les projets',
  'Certify a skill': 'Certifier une compétence',
  'Sit a Guild exam to earn a credential and raise your labor rate.': 'Passez un examen de la Guilde pour obtenir un titre et augmenter votre taux horaire.',
  'Visit the Guild': 'Aller à la Guilde',

  // ── wallet ──
  'Wallet': 'Portefeuille',
  'Your Stater (STR) balance and transaction history.': 'Votre solde Stater (STR) et l’historique des transactions.',
  'No member record linked to this account yet.': 'Aucun membre n’est encore lié à ce compte.',
  'Net worth': 'Valeur nette',
  "Liquid balance plus nominal STR you've staked across projects. Staked STR isn't spendable until each project settles.":
    'Solde liquide plus le STR nominal engagé dans vos projets. Le STR engagé n’est pas dépensable avant le règlement de chaque projet.',
  'Liquid': 'Liquide',
  'Liquid balance': 'Solde liquide',
  'spendable now': 'dépensable maintenant',
  'Spendable STR in your wallet — used to post bonds and pay Guild exam fees.':
    'STR dépensable dans votre portefeuille — sert à déposer des cautions et payer les examens de la Guilde.',
  'Nominal STR minted into project pools (your bond + declared work). Locked until each project settles, then converts to liquid.':
    'STR nominal frappé dans les pools de projet (votre caution + travail déclaré). Bloqué jusqu’au règlement de chaque projet, puis converti en liquide.',
  'Bonded ratio': 'Ratio engagé',
  'of net worth at work': 'de la valeur nette au travail',
  'Activity': 'Activité',
  'Earned by finishing projects; spent to join ({n}/join), stake, and endorse peers.':
    'Gagné en terminant des projets ; dépensé pour rejoindre ({n}/adhésion), engager et recommander des pairs.',
  'No transactions yet.': 'Aucune transaction pour le moment.'
};

export const dict: Record<Exclude<Locale, 'en'>, Table> = { zh, ja, fr };
