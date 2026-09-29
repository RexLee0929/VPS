/* ============================================================================
 *  Sub-Store  ·  文件(mihomo 配置)  ·  「脚本操作」→「快捷脚本」
 * ----------------------------------------------------------------------------
 *  粘贴位置： Sub-Store → 文件 → 你的文件 → 添加操作 → 脚本操作
 *             → 脚本类型选【快捷脚本】→ 把本文件全部内容粘进去
 *
 *  ❗【3 条硬性前提，不满足就"什么都不会生成"】
 *
 *   1) 这个「文件」的类型必须是 Mihomo 配置（内部名 mihomoConfig）。
 *      类型不对时 Sub-Store 只会执行脚本、【永远不会调用 main()】
 *      → 你就看到"没有任何策略组/规则集被创建"。
 *      自检：看 Sub-Store 日志有没有 [生成器] 开头的行。
 *
 *   2) 本脚本必须放在「从订阅添加节点」操作的【后面】。
 *
 *   3) 本脚本是【生成器】不是【修改器】：proxy-groups / rules / rule-providers
 *      全部由它自己造，你的文件里不需要预先存在这些内容。
 *
 *  ===========================================================================
 *  ⚠️ 为什么必须写"显式节点列表"，而不是用 include-all + filter？
 *
 *  我读了 mihomo 源码，这是关键结论（config/config.go:947）：
 *      slices.Sort(AllProxies)          // ← 在做 include-all / filter 之前，先按名字【字典序排序】
 *  然后 adapter/outboundgroup/parser.go:102 才用 AllProxies 去 filter 匹配：
 *      for _, p := range AllProxies { if filterReg.MatchString(p) { Proxies = append(Proxies, p) } }
 *
 *  ⇒ 任何 include-all（含带 filter 的组）拿到的节点顺序 = 【按节点名字典序】，
 *    跟你顶层 proxies 怎么排、跟你 UI 里怎么加订阅，全都无关。
 *    这就是"proxies 里顺序是对的，进了地区组顺序就不对"的真正原因。
 *
 *  ⇒ 只有【组里显式写 proxies 列表】才能保住你要的顺序（parser.go:223 getProxies 是按列表顺序取的）。
 *
 *  所以本脚本现在默认把每个组的节点【显式列出来】，顺序直接沿用 config.proxies 的顺序
 *  （= 你在 UI 里「从订阅添加节点」的追加顺序 = 天然按订阅分块）。
 *
 *  ===========================================================================
 *  ⚠️ 关于「排除」，现在都是【逐组手动勾选】，在【5】里：
 *
 *  · 信息节点（剩余流量 / 距离下次重置剩余 / 套餐到期）
 *      → 默认【全组排除】，并会从顶层 proxies 里摘掉。词表 = 【5】INFO_WORDS
 *  · 中转节点（IPv4 / IPv6 / Vmess / CF / Cloudflare）
 *      → 默认【保留】，要排除哪些组由你在【5】EXCLUDE_BY_GROUP 里逐组勾
 *
 *  每次生成都会打一张「逐组排除策略」表到日志（搜 [生成器]），
 *  照着它确认哪组滤掉了几个，再回去改 —— 这就是"手动确认"的闭环。
 * ==========================================================================*/


/* ==========================================================================
 *  ★★★★★  配置区（你要手动改的只有这几段）  ★★★★★
 * ========================================================================*/


/* --------------------------------------------------------------------------
 * 【1】订阅集定义
 * --------------------------------------------------------------------------
 *   name     = 订阅集标签，随便起，只用于分块排序/日志
 *   sub      = ★ Sub-Store 里的【订阅名】（就是「从订阅添加节点」里选的那个）
 *              开启下面 SUBSET_FROM_PRODUCE 后靠它【精确】识别节点归属
 *   keywords = 节点名关键词，Sub-Store 里没有这个订阅、或拉取失败时的兜底
 *              （匹配节点名，忽略大小写、包含匹配）
 *
 * ⚠️ 注意：keywords 匹配的是【节点名】，不是订阅名！
 *    比如订阅叫 "AK"，但节点名是「🇭🇰 香港01」，那 'AK' 一个都匹配不上。
 *    遇到"某个组一个节点都没有"，先看日志里那行"节点名："，照着真实节点名改 keywords。
 * ------------------------------------------------------------------------*/
const SUBSETS = [
  { name: '订阅一', sub: 'RexCloud', keywords: [] },
  { name: '订阅二', sub: 'AK', keywords: [] },
  { name: '订阅三', sub: 'PBC', keywords: [] },
];

/** 没归属的节点归这里。名字随便改，但不要和上面的重名。 */
const UNKNOWN = '其他';

/**
 * true  = 用【1】里的 sub（订阅名）调 Sub-Store 精确取每个订阅的节点名单来定归属
 *         —— 最准，不需要猜关键词。代价：每次生成会去拉一次这些订阅。
 * false = 只用 keywords 按节点名匹配（离线、不联网）。
 *
 * ⚠️ 拉取失败会自动降级到 keywords；再不行就全部归入 UNKNOWN
 *    （那也只是分块不生效，节点顺序仍按 proxies 原顺序，配置照样是对的）。
 */
const SUBSET_FROM_PRODUCE = true;


/* --------------------------------------------------------------------------
 * 【2】默认分块顺序
 * --------------------------------------------------------------------------
 * 只在【3】或【4】让某个组"按订阅分块"时才用得上。
 * 平时不用管 —— 正常模式保持 proxies 原顺序，那本身就已经是按订阅分块的了。
 * ------------------------------------------------------------------------*/
const GLOBAL_ORDER = ['订阅一', '订阅二', '订阅三'];


/* --------------------------------------------------------------------------
 * 【3】逐组分块排序（可选）
 * --------------------------------------------------------------------------
 * 左边 = 策略组名（一字不差），右边 = 该组的订阅集顺序。
 * 不写 = 保持 proxies 原顺序（推荐，除非某个组你确实想要不一样的分块次序）。
 *
 * 例：'Hong Kong': ['订阅二', '订阅一', '订阅三']
 * ------------------------------------------------------------------------*/
const GROUP_ORDER = {
  // 'Hong Kong':     ['订阅二', '订阅一', '订阅三'],
  // 'United States': ['订阅三', '订阅二', '订阅一'],
};


/* --------------------------------------------------------------------------
 * 【4】把某个订阅集的节点，额外塞进指定策略组
 * --------------------------------------------------------------------------
 * 格式： '策略组名': ['订阅集名', ...]（订阅集名 = 【1】里的 name）
 * 效果：该组除了自己原本的内容，再【显式】加上这些订阅集的全部节点，排在后面。
 *
 * 当前配置：RexCloud 组 = Direct + 订阅二 的全部节点
 *   （配合 GROUP_TEMPLATE 里 RexCloud 的 all:false，它不再收全部节点）
 *
 * ⚠️ 如果你看到 RexCloud 组里一个节点都没有：
 *    说明"订阅二"没识别到任何节点 → 看日志里 [produce] 那几行 + "节点名："
 * ------------------------------------------------------------------------*/
const ADD_TO_GROUP = {
  'RexCloud': ['订阅一', '订阅二', '订阅三'],
};


/* --------------------------------------------------------------------------
 * 【5】排除策略（★ 逐组手动勾选 —— 你要的"手动确认"就在这里）
 * --------------------------------------------------------------------------
 *  两个开关，每个组各管一份：
 *    info  = 排除【信息节点】：剩余流量 / 距离下次重置剩余 / 套餐到期
 *    relay = 排除【中转节点】：IPv4 / IPv6 / Vmess / CF / Cloudflare
 *
 *  DEFAULT_EXCLUDE  = 所有组的默认值
 *  EXCLUDE_BY_GROUP = 只写"和默认不一样"的组；写 true 打开、写 false 关掉、删掉回默认
 *
 *  ★ 每次生成都会在日志里打一张「逐组排除策略」表（搜 [生成器] 就能看到），
 *    照着那张表确认哪组滤掉了什么，再回来改这里 —— 这就是"手动确认"。
 *
 *  ⚠️ IPv4 / IPv6 / Cloudflare 三组【永远不要】把 relay 打开 ——
 *     它们的 filter 本身就命中中转词表，开了会把组筛空。
 * ------------------------------------------------------------------------*/

/** 「信息节点」判定词：节点名里【包含】任一即算信息节点（忽略大小写）。
 *  你机场如果还有"官网 / 客服 / 续费 / 到期时间 / 剩余"之类的假节点，往数组里加即可。
 *
 *  为什么必须排掉它们：这类名字里常带流量数字，例如「剩余流量：3904.53 GB」——
 *  里面的 "GB" 会被 Europe 的 filter 里的 GB 规则命中，不排除就真的会跑进 Europe 组。 */
const INFO_WORDS = ['剩余流量', '距离下次重置剩余', '套餐到期'];

const DEFAULT_EXCLUDE = {
  info: true,    // 信息节点：默认【全组排除】（它们不是真线路，选中也没用）
  relay: false,  // 中转节点：默认【保留】，要排除的组在下面单独勾
};

const EXCLUDE_BY_GROUP = {
  // ── 6 个地区组：排除中转节点（= 原来 REGION_EXCLUDE 的行为，现在看得见、可逐组改）
  'RexCloud':      { info: false, relay: true },
  'Hong Kong':     { info: true, relay: true },
  'United States': { info: true, relay: true },
  'Singapore':     { info: true, relay: true },
  'Japan':         { info: true, relay: true },
  'Asia':          { info: true, relay: true },
  'Europe':        { info: true, relay: true },

  // ── 想给别的组也排除中转节点 → 取消注释：
  // 'Download': { relay: true },
  // 'Media':    { relay: true },
  // 'Steam':    { relay: true },

  // ── 想【保留】信息节点（少见）→ 写 info: false：
  // 'Direct': { info: false },
};


/* --------------------------------------------------------------------------
 * 【6】开关
 * ------------------------------------------------------------------------*/
/** true = 生成策略组 */
const GEN_GROUPS = true;
/** true = 生成 rules（覆盖文件原有的 rules） */
const GEN_RULES = true;
/** true = 生成 rule-providers（覆盖文件原有的 rule-providers） */
const GEN_RULE_PROVIDERS = true;
/**
 * true  = 把信息节点从顶层 proxies 里【摘掉】（它们不是真线路，留着只会出现在 GLOBAL 里）
 * false = 顶层 proxies 原样保留（只是不放进任何策略组）
 * ⚠️ 只要有任何一组把 info 设成 false（要留信息节点），本项自动失效，避免"组里引用了不存在的节点"。
 */
const DROP_INFO_FROM_PROXIES = true;
/** true = 顺便按订阅集重排顶层 proxies（你说 UI 里已经排好了，所以默认 false） */
const REORDER_PROXIES = false;
/** true = 打印日志 */
const LOG = true;
/** true = 日志里打印前 40 个节点名（核对关键词/排查归属时很有用） */
const LOG_NODES = true;

/** 日志前缀，方便在 Sub-Store 日志页里搜。 */
const SCOPE = '[生成器]';


/* ==========================================================================
 *  模板区：以下数据 = v2board.yaml 展开锚点后的最终配置，一般不用改
 * ========================================================================*/

/* 节点筛选正则（原样搬自模板的 Filter 锚点，mihomo 用 regexp2 支持 (?i)） */
var FILTERS = {
  HK: '(?i)香港|🇭🇰|HK|HKG|Hong ?Kong',
  US: '(?i)🇺🇸|美国|波特兰|达拉斯|俄勒冈|凤凰城|费利蒙|硅谷|拉斯维加斯|洛杉矶|圣何塞|圣克拉拉|西雅图|芝加哥|纽约|新泽西|华盛顿|迈阿密|波士顿|亚特兰大|US|USA|UnitedStates|United ?States|America',
  JP: '(?i)🇯🇵|日本|东京|大阪|京都|名古屋|福冈|埼玉|横滨|千叶|北海道|冲绳|JP|JPN|Japan',
  SG: '(?i)🇸🇬|新加坡|狮城|SG|SGP|Singapore',
  Asia: '(?i)🇹🇼|台湾|台北|新北|桃园|台中|台南|高雄|基隆|新竹|彰化|TW|TWN|Taiwan|东南亚|马来西亚|马来|吉隆坡|槟城|MY|MYS|Malaysia|Kuala ?Lumpur|泰国|泰|曼谷|TH|THA|Thailand|Bangkok|越南|越|河内|胡志明|VN|VNM|Vietnam|Hanoi|Ho ?Chi ?Minh|印度尼西亚|印尼|雅加达|ID|IDN|Indonesia|Jakarta|菲律宾|菲|马尼拉|PH|PHL|Philippines|Manila',
  EU: '(?i)🇪🇺|欧洲|英国|伦敦|(?i)(?<![A-Za-z])UK(?![A-Za-z])|(?i)(?<![A-Za-z])GB(?![A-Za-z])|GBR|United ?Kingdom|London|德国|德|法兰克福|柏林|(?i)(?<![A-Za-z])DE(?![A-Za-z])|DEU|Germany|Frankfurt|Berlin|法国|法|巴黎|(?i)(?<![A-Za-z])FR(?![A-Za-z])|FRA|France|Paris|荷兰|荷|阿姆斯特丹|(?i)(?<![A-Za-z])NL(?![A-Za-z])|NLD|Netherlands|Amsterdam|意大利|意|米兰|罗马|(?i)(?<![A-Za-z])IT(?![A-Za-z])|ITA|Italy|Milan|Rome|西班牙|西|马德里|巴塞罗那|(?i)(?<![A-Za-z])ES(?![A-Za-z])|(?i)(?<![A-Za-z])ESP(?![A-Za-z])|Spain|Madrid|Barcelona|瑞士|苏黎世|(?i)(?<![A-Za-z])CH(?![A-Za-z])|CHE|Switzerland|Zurich',
  IPv4: '(?i)IPv4|v4',
  IPv6: '(?i)IPv6|v6',
  Cloudflare: '(?i)CF|Cloudflare|Vmess',
  Game: '(?i)Game',
  Exclude: '(?i)IPv4|IPv6|Vmess|CF|Cloudflare',
};

/* 通用组引用的组名（原模板 Group 锚点，已按你的修改补上 Cloudflare） */
var GROUP_REFS = ['Direct', 'PROXY', 'RexCloud', 'Hong Kong', 'United States', 'Singapore', 'Japan', 'Asia', 'Europe', 'IPv4', 'IPv6', 'Cloudflare'];

/*
 * 策略组模板（= v2board.yaml 展开合并键后的最终结果，顺序与原文件一致）
 *   all     : true = 原模板 include-all: true（该组会收集节点）
 *   region  : true = 地区组（只用于日志打 [地区组] 标记；要不要排除中转节点看【5】）
 *   filter  : 原模板的 filter 正则（用来挑本组成员）
 *   proxies : 组内固定的「策略引用」（不是节点名），会排在节点前面
 */
var GROUP_TEMPLATE = [
  { name: 'PROXY', all: false, proxies: ['Direct', 'RexCloud', 'Hong Kong', 'United States', 'Singapore', 'Japan', 'Asia', 'Europe', 'IPv4', 'IPv6', 'Cloudflare'] },
  { name: 'Direct', all: true, proxies: ['DIRECT'] },
  { name: 'RexCloud', all: false, proxies: ['Direct'] },
  { name: 'Game', all: false, proxies: ['RiotGames'].concat(GROUP_REFS) },
  { name: 'Hong Kong', all: true, region: true, filter: FILTERS.HK, proxies: ['Direct'] },
  { name: 'United States', all: true, region: true, filter: FILTERS.US, proxies: ['Direct'] },
  { name: 'Singapore', all: true, region: true, filter: FILTERS.SG, proxies: ['Direct'] },
  { name: 'Japan', all: true, region: true, filter: FILTERS.JP, proxies: ['Direct'] },
  { name: 'Asia', all: true, region: true, filter: FILTERS.Asia, proxies: ['Direct'] },
  { name: 'Europe', all: true, region: true, filter: FILTERS.EU, proxies: ['Direct'] },
  { name: 'IPv4', all: true, filter: FILTERS.IPv4, proxies: ['Direct'] },
  { name: 'IPv6', all: true, filter: FILTERS.IPv6, proxies: ['Direct'] },
  { name: 'Cloudflare', all: true, filter: FILTERS.Cloudflare, proxies: ['Direct'] },
  { name: 'Download', all: true, proxies: GROUP_REFS },
  { name: 'Media', all: true, proxies: GROUP_REFS },
  { name: 'Bilibili', all: false, proxies: GROUP_REFS },
  { name: 'OpenAI', all: false, proxies: GROUP_REFS },
  { name: 'SSH', all: true, proxies: GROUP_REFS },
  { name: 'Steam', all: false, proxies: GROUP_REFS },
  { name: 'WeChat', all: false, proxies: ['SSH'].concat(GROUP_REFS) },
  { name: 'Telegram', all: false, proxies: GROUP_REFS },
  { name: 'OneDrive', all: false, proxies: GROUP_REFS },
  { name: 'Microsoft', all: false, proxies: GROUP_REFS },
  { name: 'YouTube', all: false, proxies: GROUP_REFS },
  { name: 'PayPal', all: false, proxies: GROUP_REFS },
  { name: 'Apple', all: false, proxies: GROUP_REFS },
  { name: 'Netflix', all: false, proxies: GROUP_REFS },
  { name: 'Disney Plus', all: false, proxies: GROUP_REFS },
  { name: 'RiotGames', all: true, filter: FILTERS.Game, proxies: ['RexCloud', 'Hong Kong', 'Singapore', 'Japan', 'Asia'] },
];

/* 规则集（rule-providers）。behavior 省略 = classical。顺序与原文件一致。 */
var RULE_PROVIDER_LIST = [
  { name: 'Bybit', url: 'https://substore.rexleepro.com/WrLL2v6inXfnUqjgrBfqaBGkK/api/file/Bybit?$options=fmt%3Dclash', path: './Rules/Bybit.yaml' },
  { name: 'Binance', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Binance/Binance_No_Resolve.yaml', path: './Rules/Binance_No_Resolve.yaml' },
  { name: 'Game', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Game/Game_No_Resolve.yaml', path: './Rules/Game_No_Resolve.yaml' },
  { name: 'GameDownload', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Game/GameDownload/GameDownload_No_Resolve.yaml', path: './Rules/GameDownload_No_Resolve.yaml' },
  { name: 'GameDownloadCN', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Game/GameDownloadCN/GameDownloadCN_No_Resolve.yaml', path: './Rules/GameDownloadCN_No_Resolve.yaml' },
  { name: 'DNS', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/DNS/DNS_No_Resolve.yaml', path: './Rules/DNS_No_Resolve.yaml' },
  { name: 'OpenAI', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/OpenAI/OpenAI_No_Resolve.yaml', path: './Rules/OpenAI_No_Resolve.yaml' },
  { name: 'Claude', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Claude/Claude_No_Resolve.yaml', path: './Rules/Claude_No_Resolve.yaml' },
  { name: 'iCloud', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/iCloud/iCloud_No_Resolve.yaml', path: './Rules/iCloud.yaml' },
  { name: 'Apple', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Apple/Apple_No_Resolve.yaml', path: './Rules/Apple_No_Resolve.yaml' },
  { name: 'Apple_Domain', behavior: 'domain', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Apple/Apple_Domain.yaml', path: './Rules/Apple_Domain.yaml' },
  { name: 'Netflix', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Netflix/Netflix_Classical_No_Resolve.yaml', path: './Rules/Netflix_Classical_No_Resolve.yaml' },
  { name: 'Disney Plus', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Disney/Disney_No_Resolve.yaml', path: './Rules/Disney_Plus_No_Resolve.yaml' },
  { name: 'YouTube', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/YouTube/YouTube_No_Resolve.yaml', path: './Rules/Media/YouTube_No_Resolve.yaml' },
  { name: 'PayPal', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/PayPal/PayPal_No_Resolve.yaml', path: './Rules/PayPal_No_Resolve.yaml' },
  { name: 'OneDrive', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/OneDrive/OneDrive_No_Resolve.yaml', path: './Rules/OneDrive_No_Resolve.yaml' },
  { name: 'Microsoft', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Microsoft/Microsoft_No_Resolve.yaml', path: './Rules/Microsoft_No_Resolve.yaml' },
  { name: 'TikTok', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/TikTok/TikTok_No_Resolve.yaml', path: './Rules/TikTok_No_Resolve.yaml' },
  { name: 'WeChat', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/WeChat/WeChat_No_Resolve.yaml', path: './Rules/WeChat_No_Resolve.yaml' },
  { name: 'BiliBili', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/BiliBili/BiliBili_No_Resolve.yaml', path: './Rules/BiliBili_No_Resolve.yaml' },
  { name: 'Telegram', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Telegram/Telegram_No_Resolve.yaml', path: './Rules/Telegram_No_Resolve.yaml' },
  { name: 'Google', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Google/Google_No_Resolve.yaml', path: './Rules/Google_No_Resolve.yaml' },
  { name: 'Steam', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Steam/Steam_No_Resolve.yaml', path: './Rules/Steam_No_Resolve.yaml' },
  { name: 'Gemini', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Gemini/Gemini_No_Resolve.yaml', path: './Rules/Gemini_No_Resolve.yaml' },
  { name: 'Global', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Global/Global_Classical_No_Resolve.yaml', path: './Rules/Global_Classical_No_Resolve.yaml' },
  { name: 'ChinaMax', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_Classical_No_Resolve.yaml', path: './Rules/ChinaMax_Classical_No_Resolve.yaml' },
  { name: 'Advertising', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Advertising/Advertising_Classical_No_Resolve.yaml', path: './Rules/Advertising_Classical_No_Resolve.yaml' },
  { name: 'Spotify', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Spotify/Spotify_No_Resolve.yaml', path: './Rules/Spotify_No_Resolve.yaml' },
  { name: 'Cloudflare', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Cloudflare/Cloudflare_No_Resolve.yaml', path: './Rules/Cloudflare_No_Resolve.yaml' },
  { name: 'Razer', url: 'https://raw.githubusercontent.com/ericz15/ios_rule_script/master/rule/Clash/Razer/Razer_No_Resolve.yaml', path: './Rules/Razer_No_Resolve.yaml' },
];

/* 规则（顺序即匹配优先级，与原文件一致） */
var RULES = [
  'RULE-SET,Bybit,United States',
  'RULE-SET,Binance,United States',
  'RULE-SET,Steam,Steam',
  'RULE-SET,Game,Game',
  'RULE-SET,GameDownload,Download',
  'RULE-SET,GameDownloadCN,Direct',
  'RULE-SET,DNS,PROXY',
  'DOMAIN-SUFFIX,oaistatic.com,OpenAI',
  'DOMAIN-SUFFIX,oaiusercontent.com,OpenAI',
  'DOMAIN-SUFFIX,webpubsub.azure.com,OpenAI',
  'DOMAIN-SUFFIX,chatgpt.com,OpenAI',
  'DOMAIN-SUFFIX,claudeusercontent.com,OpenAI',
  'RULE-SET,OpenAI,OpenAI',
  'RULE-SET,Gemini,OpenAI',
  'RULE-SET,Claude,OpenAI',
  'IP-CIDR,17.0.0.0/8,Apple',
  'RULE-SET,iCloud,Apple',
  'RULE-SET,Apple,Apple',
  'RULE-SET,Apple_Domain,Apple',
  'RULE-SET,Netflix,Netflix',
  'RULE-SET,Disney Plus,Disney Plus',
  'RULE-SET,YouTube,YouTube',
  'RULE-SET,PayPal,PayPal',
  'RULE-SET,OneDrive,OneDrive',
  'RULE-SET,Microsoft,Microsoft',
  'RULE-SET,TikTok,United States',
  'RULE-SET,WeChat,WeChat',
  'RULE-SET,BiliBili,Bilibili',
  'RULE-SET,Telegram,Telegram',
  'RULE-SET,Spotify,Media',
  'RULE-SET,Razer,PROXY',
  'RULE-SET,Google,PROXY',
  'RULE-SET,Global,PROXY',
  'IP-CIDR,192.168.0.0/16,DIRECT',
  'IP-CIDR,10.0.0.0/8,DIRECT',
  'IP-CIDR,172.16.0.0/12,DIRECT',
  'IP-CIDR,127.0.0.0/8,DIRECT',
  'IP-CIDR,100.64.0.0/10,DIRECT',
  'IP-CIDR,224.0.0.0/4,DIRECT',
  'GEOIP,CN,Direct,no-resolve',
  'MATCH,PROXY',
];


/* ==========================================================================
 *  实现区：正常使用不用改
 * ========================================================================*/

/** 取节点名（节点可能是对象，也可能是纯字符串） */
function nodeNameOf(p) {
  if (typeof p === 'string') return p;
  if (p && typeof p.name === 'string') return p.name;
  return '';
}

/** 按 keywords 判断节点属于哪个订阅集（忽略大小写、包含匹配） */
function subsetByKeywords(name) {
  var low = String(name).toLowerCase();
  for (var i = 0; i < SUBSETS.length; i++) {
    var kws = SUBSETS[i].keywords || [];
    for (var j = 0; j < kws.length; j++) {
      var k = kws[j];
      if (!k) continue;
      if (low.indexOf(String(k).toLowerCase()) !== -1) return SUBSETS[i].name;
    }
  }
  return UNKNOWN;
}

/** 某组的订阅集顺序（补全没写到的，保证不丢块） */
function orderFor(groupName) {
  var listed = (groupName && GROUP_ORDER[groupName]) || GLOBAL_ORDER || [];
  var out = [];
  var i;
  for (i = 0; i < listed.length; i++) {
    if (listed[i] && out.indexOf(listed[i]) === -1) out.push(listed[i]);
  }
  for (i = 0; i < SUBSETS.length; i++) {
    if (out.indexOf(SUBSETS[i].name) === -1) out.push(SUBSETS[i].name);
  }
  if (out.indexOf(UNKNOWN) === -1) out.push(UNKNOWN);
  return out;
}

/** 稳定排序：按订阅集名次排；名次相同保持原顺序 */
function orderNodes(list, subsetByName, order) {
  var rank = {};
  for (var i = 0; i < order.length; i++) rank[order[i]] = i;
  return list
    .map(function (n, idx) {
      var r = rank[subsetByName[n]];
      return { n: n, i: idx, r: typeof r === 'number' ? r : 9999 };
    })
    .sort(function (a, b) {
      return a.r !== b.r ? a.r - b.r : a.i - b.i;
    })
    .map(function (x) {
      return x.n;
    });
}

/**
 * 编译 mihomo 的 filter / exclude-filter 为正则（仅用于在 JS 侧挑本组成员）。
 * mihomo 用 regexp2(PCRE 风格) 支持裸 (?i)，JS 的 RegExp 不认，所以剥掉并改用 i 标志。
 * 编译失败退化成宽松包含匹配，绝不静默丢节点。
 */
function compileFilter(src) {
  var out = [];
  if (!src) return out;
  // 反引号(0x60) 是 mihomo 用来分隔多个正则的符号；这里刻意不写进源码
  var parts = String(src).split('\x60');
  for (var i = 0; i < parts.length; i++) {
    var raw = parts[i];
    if (!raw) continue;
    var js = raw.replace(/\(\?i\)/g, '').replace(/\(\?i:/g, '(?:');
    try {
      out.push(wrapRe(new RegExp(js, 'i')));
    } catch (e) {
      if (LOG) console.log(SCOPE + ' WARN 正则无法在 JS 编译，改用宽松匹配: ' + raw);
      out.push(looseMatcher(raw));
    }
  }
  return out;
}

function wrapRe(re) {
  return {
    test: function (s) {
      re.lastIndex = 0;
      return re.test(s);
    },
  };
}

function looseMatcher(src) {
  var toks = String(src)
    .split('|')
    .map(function (t) {
      return t
        .replace(/\(\?<?[=!]?[^)]*\)/g, '')
        .replace(/\(\?:/g, '')
        .replace(/[\^$.*+?()\[\]{}\\]/g, '')
        .trim()
        .toLowerCase();
    })
    .filter(function (t) {
      return t.length > 0;
    });
  return {
    test: function (s) {
      var low = String(s).toLowerCase();
      for (var i = 0; i < toks.length; i++) {
        if (low.indexOf(toks[i]) !== -1) return true;
      }
      return false;
    },
  };
}

function matchAny(res, str) {
  for (var i = 0; i < res.length; i++) {
    if (res[i].test(str)) return true;
  }
  return false;
}

/** 规则集：behavior 省略 = classical */
function buildRuleProviders() {
  var out = {};
  for (var i = 0; i < RULE_PROVIDER_LIST.length; i++) {
    var p = RULE_PROVIDER_LIST[i];
    out[p.name] = {
      type: 'http',
      interval: 86400,
      behavior: p.behavior || 'classical',
      format: 'text',
      url: p.url,
      path: p.path,
    };
  }
  return out;
}

/** 用 filter 从节点名里挑成员（排除交给 applyExclude 统一处理） */
function membersByFilter(nodes, filter) {
  var inc = compileFilter(filter);
  var out = [];
  for (var i = 0; i < nodes.length; i++) {
    if (inc.length && !matchAny(inc, nodes[i])) continue;
    out.push(nodes[i]);
  }
  return out;
}

/* --------------------------------------------------------------------------
 *  排除策略实现（【5】用）
 * ------------------------------------------------------------------------*/

/** 左填充：让日志里的组名对齐 */
function padRight(s, n) {
  s = String(s);
  while (s.length < n) s += ' ';
  return s;
}

/** 转义正则元字符（刻意不出现"美元符紧跟左花括号"的组合，免得混进模板字符串出事） */
function escapeRe(s) {
  return String(s).replace(/[.*+?^$()|\[\]{}\\]/g, function (m) {
    return '\\' + m;
  });
}

/** 节点名是不是「信息节点」（命中 INFO_WORDS 任一，忽略大小写包含匹配） */
function isInfoNode(name) {
  var low = String(name).toLowerCase();
  for (var i = 0; i < INFO_WORDS.length; i++) {
    var w = INFO_WORDS[i];
    if (w && low.indexOf(String(w).toLowerCase()) !== -1) return true;
  }
  return false;
}

/** 信息节点转成 mihomo 正则（只在"退回 include-all 动态模式"时当 exclude-filter 用） */
function infoFilterPattern() {
  var parts = [];
  for (var i = 0; i < INFO_WORDS.length; i++) {
    if (INFO_WORDS[i]) parts.push(escapeRe(INFO_WORDS[i]));
  }
  return parts.length ? '(?i)' + parts.join('|') : '';
}

/** 把多条 mihomo 正则拼成一条（只保留开头一个 (?i)，中间的不重复写） */
function joinFilters(list) {
  var out = [];
  for (var i = 0; i < list.length; i++) {
    var s = String(list[i] || '').trim();
    if (!s) continue;
    out.push(s.replace(/^\(\?i\)/, ''));
  }
  return out.length ? '(?i)' + out.join('|') : '';
}

/** 中转节点判定（复用模板里的 Exclude 正则），第一次调用时编译并缓存 */
var _relayRe = null;
function isRelayNode(name) {
  if (_relayRe === null) _relayRe = compileFilter(FILTERS.Exclude);
  return matchAny(_relayRe, String(name));
}

/**
 * 某组的排除策略。
 * EXCLUDE_BY_GROUP 里写了就用写的；没写就回落 DEFAULT_EXCLUDE。
 */
function excludeOptFor(groupName) {
  var d = DEFAULT_EXCLUDE || {};
  var o = (EXCLUDE_BY_GROUP && EXCLUDE_BY_GROUP[groupName]) || {};
  return {
    info: o.info === undefined ? d.info !== false : o.info === true,
    relay: o.relay === undefined ? d.relay === true : o.relay === true,
  };
}

/** 按策略过滤一组成员，同时回报被滤掉的数量 */
function applyExclude(list, opt) {
  var out = [];
  var dropped = { info: 0, relay: 0 };
  for (var i = 0; i < list.length; i++) {
    var n = list[i];
    if (opt.info && isInfoNode(n)) {
      dropped.info++;
      continue;
    }
    if (opt.relay && isRelayNode(n)) {
      dropped.relay++;
      continue;
    }
    out.push(n);
  }
  return { list: out, dropped: dropped };
}

/**
 * 建立「节点名 → 订阅集」表。
 * 优先用 sub（订阅名）调 produceArtifact 精确取名单；失败/未开则退回 keywords。
 */
async function buildSubsetMap(nodeNames) {
  var map = {};
  var i, j, n;

  if (SUBSET_FROM_PRODUCE && typeof produceArtifact === 'function') {
    for (i = 0; i < SUBSETS.length; i++) {
      var s = SUBSETS[i];
      if (!s.sub) continue;
      try {
        var arr = await produceArtifact({
          type: s.type || 'subscription',
          name: s.sub,
          platform: 'ClashMeta',
          produceType: 'internal',
          produceOpts: { 'include-unsupported-proxy': true },
        });
        var names = [];
        if (Array.isArray(arr)) {
          for (j = 0; j < arr.length; j++) {
            n = nodeNameOf(arr[j]);
            if (n) names.push(n);
          }
        }
        var hit = 0;
        for (j = 0; j < names.length; j++) {
          if (map[names[j]] === undefined) {
            map[names[j]] = s.name;
            hit++;
          }
        }
        if (LOG) {
          console.log(SCOPE + ' [produce] 订阅 "' + s.sub + '" → 取到 ' + names.length + ' 个节点名，其中 ' + hit + ' 个在本文件里');
        }
      } catch (e) {
        if (LOG) {
          console.log(SCOPE + ' WARN [produce] 订阅 "' + s.sub + '" 拉取失败，将退回关键词匹配：' + (e && e.message ? e.message : e));
        }
      }
    }
  }

  /* 剩下的用关键词兜底 */
  for (i = 0; i < nodeNames.length; i++) {
    n = nodeNames[i];
    if (map[n] === undefined) map[n] = subsetByKeywords(n);
  }
  return map;
}

/** 生成全部策略组 */
function buildGroups(nodes, subsetByName) {
  var groups = [];
  var report = [];

  for (var gi = 0; gi < GROUP_TEMPLATE.length; gi++) {
    var def = GROUP_TEMPLATE[gi];
    var refs = (def.proxies || []).slice();
    var filt = def.filter || '';
    var opt = excludeOptFor(def.name);
    var dropped = { info: 0, relay: 0 };

    /* --- 该组自己的成员（保持 nodes 原顺序），再按该组策略排除 --- */
    var members = [];
    if (def.all) {
      members = def.filter ? membersByFilter(nodes, filt) : nodes.slice();
      var r1 = applyExclude(members, opt);
      members = r1.list;
      dropped.info += r1.dropped.info;
      dropped.relay += r1.dropped.relay;
    }

    /* --- 【4】额外塞入指定订阅集的节点（同样走该组的排除策略） --- */
    var addSubs = ADD_TO_GROUP[def.name] || [];
    var addMembers = [];
    if (addSubs.length) {
      var pool = [];
      for (var ni = 0; ni < nodes.length; ni++) {
        var nm = nodes[ni];
        if (addSubs.indexOf(subsetByName[nm]) !== -1 && members.indexOf(nm) === -1 && pool.indexOf(nm) === -1) {
          pool.push(nm);
        }
      }
      var r2 = applyExclude(pool, opt);
      addMembers = r2.list;
      dropped.info += r2.dropped.info;
      dropped.relay += r2.dropped.relay;
      if (!addMembers.length && LOG) {
        console.log(SCOPE + ' WARN "' + def.name + '" 想追加 ' + addSubs.join('/') + '，但一个节点都没匹配到 —— 检查【1】的 sub/keywords，或它的节点被【5】的排除策略滤掉了');
      }
    }

    /* --- 【3】该组是否要按订阅分块重排 --- */
    var allMembers = members.concat(addMembers);
    if (Object.prototype.hasOwnProperty.call(GROUP_ORDER, def.name) && allMembers.length) {
      allMembers = orderNodes(allMembers, subsetByName, orderFor(def.name));
    }

    /* --- 组装 --- */
    var g = { name: def.name, type: 'select', 'disable-udp': false, hidden: false };

    if (!def.all && !allMembers.length) {
      /* 纯引用组（只指向别的组）：不收节点 */
      g['include-all'] = false;
      g.proxies = refs;
    } else if (allMembers.length) {
      /* 显式列表模式 —— 只有这样才能保住你要的顺序 */
      g['include-all'] = false;
      g.proxies = refs.concat(allMembers);
    } else {
      /* 兜底：本文件里没有可用节点 → 退回 include-all + filter
         （此时顺序由 mihomo 排序，但至少配置可用；排除仍靠 exclude-filter 兜住） */
      g['include-all'] = true;
      if (filt) g.filter = filt;
      var exStr = joinFilters([opt.relay ? FILTERS.Exclude : '', opt.info ? infoFilterPattern() : '']);
      if (exStr) g['exclude-filter'] = exStr;
      g.proxies = refs;
      if (LOG) console.log(SCOPE + ' WARN "' + def.name + '" 没有可用节点，退回 include-all 动态收取');
    }

    groups.push(g);

    /* --- 逐组排除策略报告（"手动确认"就看这张表） --- */
    if (def.all) {
      var note = '';
      if (dropped.info || dropped.relay) note = '  ← 滤掉 信息' + dropped.info + ' / 中转' + dropped.relay;
      report.push(
        '  ' + padRight(def.name, 16) +
        (def.region ? '[地区组] ' : '         ') +
        'info=' + (opt.info ? '排除' : '保留') +
        '  relay=' + (opt.relay ? '排除' : '保留') +
        '  → 实收 ' + allMembers.length + ' 个' + note
      );
    }

    if (LOG && allMembers.length) {
      console.log(SCOPE + ' ' + def.name + ' ← 显式 ' + allMembers.length + ' 个节点');
    }
  }

  if (LOG && report.length) {
    console.log(SCOPE + ' ── 逐组排除策略（改【5】EXCLUDE_BY_GROUP / DEFAULT_EXCLUDE）──');
    for (var ri = 0; ri < report.length; ri++) console.log(SCOPE + report[ri]);
  }

  return groups;
}

/**
 * Sub-Store 会调用这个函数：传入解析好的 config 对象，把返回值写回文件。
 * 【不要改函数名】必须是 main。
 */
async function main(config) {
  if (!config || typeof config !== 'object') {
    if (LOG) console.log(SCOPE + ' config 不是对象（文件类型可能不是 Mihomo 配置），跳过');
    return config;
  }

  /* ---- 收集节点（去重、保持原顺序） ---- */
  var proxies = Array.isArray(config.proxies) ? config.proxies : [];
  var nodes = [];
  for (var i = 0; i < proxies.length; i++) {
    var n = nodeNameOf(proxies[i]);
    if (!n || nodes.indexOf(n) !== -1) continue;
    nodes.push(n);
  }

  /* ---- 信息节点盘点（先告诉你有哪些，方便手动确认要不要排除） ---- */
  var infoNodes = [];
  for (i = 0; i < nodes.length; i++) {
    if (isInfoNode(nodes[i])) infoNodes.push(nodes[i]);
  }

  /* ---- 归属表 ---- */
  var subsetByName = await buildSubsetMap(nodes);

  if (LOG) {
    var bucket = {};
    for (i = 0; i < nodes.length; i++) {
      var s = subsetByName[nodes[i]] || UNKNOWN;
      bucket[s] = (bucket[s] || 0) + 1;
    }
    var parts = [];
    for (i = 0; i < SUBSETS.length; i++) parts.push(SUBSETS[i].name + '=' + (bucket[SUBSETS[i].name] || 0));
    parts.push(UNKNOWN + '=' + (bucket[UNKNOWN] || 0));
    console.log(SCOPE + ' 节点 ' + nodes.length + ' 个：' + parts.join(' / '));
    if (infoNodes.length) {
      console.log(SCOPE + ' 信息节点 ' + infoNodes.length + ' 个（词表 INFO_WORDS）：' + infoNodes.slice(0, 10).join(' | ') + (infoNodes.length > 10 ? ' | ...' : ''));
    } else {
      console.log(SCOPE + ' 信息节点 0 个 —— INFO_WORDS 没命中任何节点名');
    }
    if (LOG_NODES && nodes.length) {
      console.log(SCOPE + ' 节点名：' + nodes.slice(0, 40).join(' | ') + (nodes.length > 40 ? ' | ...' : ''));
    }
  }

  /* ---- 生成策略组 ---- */
  if (GEN_GROUPS) {
    config['proxy-groups'] = buildGroups(nodes, subsetByName);
    if (LOG) console.log(SCOPE + ' 已生成策略组 ' + config['proxy-groups'].length + ' 个');
  }

  /* ---- 把信息节点从顶层 proxies 里摘掉 ---- */
  if (DROP_INFO_FROM_PROXIES && infoNodes.length) {
    var keepsInfo = false;
    for (i = 0; i < GROUP_TEMPLATE.length; i++) {
      if (!excludeOptFor(GROUP_TEMPLATE[i].name).info) {
        keepsInfo = true;
        break;
      }
    }
    if (keepsInfo) {
      if (LOG) console.log(SCOPE + ' 有组把 info 设成 false（要留信息节点）→ 顶层 proxies 保持原样');
    } else {
      var kept = [];
      for (i = 0; i < proxies.length; i++) {
        var kn = nodeNameOf(proxies[i]);
        if (kn && isInfoNode(kn)) continue;
        kept.push(proxies[i]);
      }
      config.proxies = kept;
      proxies = kept;
      if (LOG) console.log(SCOPE + ' 已从顶层 proxies 摘掉 ' + infoNodes.length + ' 个信息节点');
    }
  }

  /* ---- 可选：按订阅集重排顶层 proxies ---- */
  if (REORDER_PROXIES && proxies.length) {
    var byName = {};
    var rest = [];
    var present = [];
    for (i = 0; i < proxies.length; i++) {
      n = nodeNameOf(proxies[i]);
      if (!n) {
        rest.push(proxies[i]);
        continue;
      }
      if (!(n in byName)) {
        byName[n] = proxies[i];
        present.push(n);
      }
    }
    var ordered = orderNodes(present, subsetByName, orderFor(''));
    var rebuilt = [];
    for (i = 0; i < ordered.length; i++) rebuilt.push(byName[ordered[i]]);
    config.proxies = rebuilt.concat(rest);
    if (LOG) console.log(SCOPE + ' 已按订阅集重排顶层 proxies');
  }

  /* ---- 生成规则 ---- */
  if (GEN_RULES) {
    config.rules = RULES.slice();
    if (LOG) console.log(SCOPE + ' 已生成规则 ' + config.rules.length + ' 条');
  }

  /* ---- 生成规则集 ---- */
  if (GEN_RULE_PROVIDERS) {
    config['rule-providers'] = buildRuleProviders();
    if (LOG) {
      var cnt = 0;
      for (var k in config['rule-providers']) {
        if (Object.prototype.hasOwnProperty.call(config['rule-providers'], k)) cnt++;
      }
      console.log(SCOPE + ' 已生成规则集 ' + cnt + ' 个');
    }
  }

  return config;
}
