//
//  KnowledgeBase.swift
//  MacCQ
//

import Foundation

/// 一条内置知识要点
struct KnowledgeEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let keywords: [String]
    let content: String
}

/// 内置的中国业余无线电操作证考试知识库。
/// 依据《业余无线电台管理办法》（工业和信息化部令第 67 号）及操作技术能力验证大纲整理，
/// 用于在 AI 答疑与成绩分析时自动补充相关背景知识。
enum KnowledgeBase {

    static let all: [KnowledgeEntry] = [

        KnowledgeEntry(
            id: "licence-class",
            title: "操作证书类别与权限",
            category: "法律法规",
            keywords: ["A类", "B类", "C类", "25瓦", "1000瓦", "功率", "频段", "操作证书", "验证证书", "权限"],
            content: "业余无线电台操作技术能力分 A、B、C 三类。A 类可在 30–3000MHz 业余频段工作，最大发射功率不超过 25 瓦。B 类在 30MHz 以下频段功率小于 15 瓦，或 30MHz 以上不超过 25 瓦。C 类在 30MHz 以下不超过 1000 瓦，或 30MHz 以上不超过 25 瓦。未成年人可设置使用 30–3000MHz、不大于 25 瓦的业余电台。"),

        KnowledgeEntry(
            id: "licence-condition",
            title: "参加各类验证的条件",
            category: "法律法规",
            keywords: ["验证条件", "B类", "C类", "6个月", "18个月", "操作技术能力验证", "执照"],
            content: "参加 A 类验证应熟悉无线电管理规定并具备一定的操作技术能力；参加 B 类验证应已依法取得业余电台执照 6 个月以上并有实际操作经验；参加 C 类验证应已取得载明 30MHz 以下频段的业余电台执照 18 个月以上。"),

        KnowledgeEntry(
            id: "exam-standard",
            title: "各类别考核标准",
            category: "法律法规",
            keywords: ["考试", "题目数量", "及格", "答对", "40题", "60题", "90题", "多选题", "答题时间"],
            content: "A 类验证试卷 40 题（单选 32、多选 8），答题 40 分钟，答对 30 题合格；B 类 60 题（单选 45、多选 15），60 分钟，答对 45 题合格；C 类 90 题（单选 70、多选 20），90 分钟，答对 70 题合格。多选题必须与标准答案完全一致，多选或少选均不得分。"),

        KnowledgeEntry(
            id: "regulation",
            title: "法规体系与管理机构",
            category: "法律法规",
            keywords: ["无线电管理条例", "管理办法", "工业和信息化部", "无线电管理机构", "ITU", "频率划分规定", "民法典", "频谱资源", "国家所有"],
            content: "《中华人民共和国无线电管理条例》是行政法规；《业余无线电台管理办法》由工业和信息化部发布（第 67 号令，2024 年 3 月 1 日施行）。无线电管理由国家无线电管理机构和省、自治区、直辖市无线电管理机构实施。无线电频谱资源属于国家所有（《民法典》第二百五十二条）。国际电信联盟（ITU）负责国际无线电管理；“业余业务”的定义出自《中华人民共和国无线电频率划分规定》。"),

        KnowledgeEntry(
            id: "station-setup",
            title: "设置业余电台的条件与执照",
            category: "法律法规",
            keywords: ["设置电台", "条件", "执照", "型号核准", "呼号", "有效期", "注销", "变更", "检查"],
            content: "设置、使用业余电台应熟悉无线电管理规定、通过相应操作技术能力验证，且发射设备依法取得型号核准（自制、改装设备须符合国家标准且频率仅限业余业务频段）。电台执照载明设台人、操作技术能力类别与编号、呼号、台址/设置区域、使用频率、发射功率、执照编号、颁发日期、有效期和发证机关等。执照有效期届满应提前 30 个工作日申请更换；注销后应在 60 个工作日内拆除电台及天线。"),

        KnowledgeEntry(
            id: "station-use",
            title: "业余电台的使用规定",
            category: "法律法规",
            keywords: ["用途", "技术研究", "普及", "牟利", "转发", "广播", "应急通信", "无关信号", "中继台", "QSL", "日志"],
            content: "业余电台只能用于相互通信、技术研究和自我训练，不得用于牟利，不得转发广播电台、互联网聊天、电话通话等内容。只有发生重大突发自然灾害等情况时，才可接受有关部门指定的应急通信任务。依法设置的中继台应向覆盖区域内的电台提供平等服务。通联应填写电台日志，可交换 QSL 卡片确认联络；接收到非业余业务的信息时不得传播、公布。"),

        KnowledgeEntry(
            id: "callsign",
            title: "呼号管理",
            category: "法律法规",
            keywords: ["呼号", "前缀", "分配", "指配", "客席操作", "移动操作", "异地", "盗用", "出租"],
            content: "业余电台呼号由国家无线电管理机构统一编制和分配，颁发电台执照时一并核发。在他人电台上操作（客席操作）时，应使用所操作电台的呼号或实际操作人员的呼号；移动和异地操作也须遵守呼号使用规则。盗用、出租、出借、转让、私自编制或违法使用呼号均属违法。"),

        KnowledgeEntry(
            id: "frequency-manage",
            title: "频率的划分、分配与指配",
            category: "频率管理",
            keywords: ["划分", "分配", "指配", "主要业务", "次要业务", "频率管理", "频率使用", "平等"],
            content: "划分是把特定频带列入频率划分表，规定可在指定条件下供某种业务使用；分配是把频率或频道规定由一个或多个部门在指定区域使用；指配是把频率或频道批准给具体电台在规定条件下使用。主要业务受保护，次要业务不得对主要业务产生有害干扰，也不得要求保护。任何业余电台享有平等的频率使用权；发起呼叫前应先守听，确认频率空闲。"),

        KnowledgeEntry(
            id: "bands",
            title: "常用业余频段",
            category: "频率管理",
            keywords: ["HF", "VHF", "UHF", "频段", "米波段", "主要业务", "次要业务", "50MHz", "144MHz", "430MHz", "WARC"],
            content: "HF 为 3–30MHz，VHF 为 30–300MHz，UHF 为 300–3000MHz。50–54MHz、144–146MHz 等频段业余业务作为主要业务；430–440MHz 等为次要业务。WARC 频段包括 10.1–10.15MHz、18.068–18.168MHz、24.89–24.99MHz。业余业务与其它业务共用频段时，应遵守频率划分表规定的业务类别。"),

        KnowledgeEntry(
            id: "qcode",
            title: "常用 Q 简语与缩语",
            category: "通信操作",
            keywords: ["Q简语", "QRL", "QRM", "QRN", "QRZ", "QSL", "QTH", "QSY", "QRP", "QRO", "QRT", "QSO", "73", "CQ", "DE", "RST", "RIG", "ANT", "SWR", "OM", "YL"],
            content: "QRL 表示频率有人使用或询问是否被占用；QRM 指人为干扰，QRN 指天电等自然干扰；QRZ 意为谁在呼叫我；QSL 表示确认收信或交换卡片；QTH 为电台位置；QSY 为改变频率；QRP 为降低功率/小功率，QRO 为增大功率；QRT 为停止发射；QSO 指直接通信。缩语中 CQ 为普遍呼叫，DE 表示“来自”，73 表示美好祝愿，OM 指老朋友，YL 指女操作员，RIG 指电台设备，SWR 指驻波比。"),

        KnowledgeEntry(
            id: "procedure",
            title: "通信程序与信号报告",
            category: "通信操作",
            keywords: ["呼叫", "应答", "信号报告", "RST", "字母解释法", "守听", "双方呼号", "59"],
            content: "发起呼叫前应先守听，确认频率空闲后再呼叫。双方通联必须互发正确的呼号和信号报告。话务常用 RST 信号报告：R 为可读性（1–5）、S 为信号强度（1–9）、T 为音调（仅 CW）。话务中信号很好常用“59”。字母解释法用单词拼读呼号，如 Alpha、Bravo、Charlie、Delta 等。"),

        KnowledgeEntry(
            id: "geo",
            title: "CQ 分区、ITU 分区与网格定位",
            category: "通信操作",
            keywords: ["CQ分区", "ITU分区", "梅登海德", "网格", "Maidenhead", "经纬度", "IARU", "地理"],
            content: "ITU 将世界划分为 3 个区，中国属于第 3 区。CQ 分区共 40 个，中国主要位于第 23、24 区。梅登海德网格（Maidenhead Grid Locator）用经、纬度对地理位置进行编码，常用于业余无线电定位和竞赛。国际业余无线电联盟（IARU）是各国业余无线电组织的国际联合体。"),

        KnowledgeEntry(
            id: "propagation",
            title: "无线电波与传播",
            category: "系统原理",
            keywords: ["电波", "传播", "电离层", "D层", "E层", "F层", "天波", "地波", "视距", "波长", "频率", "太阳活动"],
            content: "无线电波是频率低于 3000GHz、在空间传播的电磁波。波长（米）≈ 300 / 频率（MHz）。HF 主要靠电离层反射的天波传播：D 层白天吸收较强、夜间消失，E 层和 F 层可反射 HF，F 层受太阳活动影响最大，太阳活动高年有利于短波远距离通信。VHF/UHF 以视距传播为主，也可通过电离层 E 层、对流层散射、流星余迹和业余卫星传播。频率越高越容易穿透电离层而不被反射。"),

        KnowledgeEntry(
            id: "antenna",
            title: "天线与馈线",
            category: "系统原理",
            keywords: ["天线", "偶极", "半波", "垂直", "八木", "定向", "增益", "dBi", "dBd", "极化", "馈线", "同轴", "阻抗", "驻波比", "巴伦", "SWR", "匹配"],
            content: "常见天线有半波偶极天线（DP）、垂直接地天线（GP）和八木定向天线（YAGI）。天线增益以理想点源（dBi）或半波偶极天线（dBd）为参考，0 dBd = 2.15 dBi。收发天线极化方向一致时接收效果最好。业余常用 50Ω 同轴电缆馈电。驻波比（SWR）越接近 1:1 越好，过大说明阻抗不匹配、反射功率大，可用巴伦和天线调谐器改善。半波偶极天线长度（米）≈ 142.5 / 频率（MHz）。"),

        KnowledgeEntry(
            id: "equipment",
            title: "收发信机与调制方式",
            category: "系统原理",
            keywords: ["调制", "AM", "FM", "SSB", "CW", "带宽", "收发信机", "中继台", "双工器", "数字", "FT8", "APRS", "SSTV", "灵敏度", "选择性"],
            content: "模拟调制方式主要有 AM、FM、SSB（单边带）和 CW。HF 长途话务常用 SSB，VHF/UHF 本地通联常用 FM。带宽方面 CW 最窄，SSB 约 2–3kHz，FM 较宽。接收机主要指标包括灵敏度、选择性、动态范围和频率稳定度。中继台采用异频收发并配双工器，可扩大覆盖范围。常见数字与图像模式有 RTTY、PSK31、FT8、Packet、APRS、SSTV 等。"),

        KnowledgeEntry(
            id: "power-db",
            title: "功率计算与分贝",
            category: "系统原理",
            keywords: ["功率", "分贝", "dB", "dBm", "增益", "欧姆定律", "P=UI", "换算"],
            content: "功率 P = U × I = I²R = U²/R。分贝用于表示倍数：功率比 dB = 10lg(P1/P2)，电压比 dB = 20lg(U1/U2)。3dB 约等于功率翻倍或减半，6dB 约等于 4 倍，10dB 等于 10 倍。天线增益用 dBi（相对理想点源）或 dBd（相对半波偶极天线）表示，0 dBd = 2.15 dBi。"),

        KnowledgeEntry(
            id: "electric",
            title: "用电安全与防雷",
            category: "安全防护",
            keywords: ["用电安全", "防雷", "接地", "避雷", "雷电", "电源", "高压", "检修"],
            content: "架设和使用业余电台要注意用电安全：检修设备应断开电源，避免接触高压和带电部件。天线塔、馈线和电台应可靠接地。雷雨天气应停止发射，断开天线与电源连接，并安装避雷器。良好的接地既能防雷，也有助于降低干扰。"),

        KnowledgeEntry(
            id: "emc",
            title: "电磁兼容与射频干扰",
            category: "电磁兼容",
            keywords: ["电磁兼容", "射频干扰", "TVI", "BCI", "谐波", "杂散", "屏蔽", "滤波", "共模", "接地", "辐射防护"],
            content: "业余电台不得对其它无线业务造成有害干扰。常见射频干扰来自谐波、杂散发射和互调，可通过加装低通滤波器、共模扼流、屏蔽和良好接地来抑制，必要时降低发射功率或改用定向天线。电磁辐射应遵守国家电磁环境控制限值，功率超过豁免水平的设备需进行评估。发现干扰应先检查设备、降低功率，仍无法消除时应停止发射。"),

        KnowledgeEntry(
            id: "penalty",
            title: "违法行为的处罚",
            category: "法律法规",
            keywords: ["处罚", "罚款", "警告", "没收", "吊销", "擅自设置", "干扰", "伪造", "转让", "刑事责任"],
            content: "对擅自设置使用业余电台、干扰无线电业务、以不正当手段取得执照、涂改伪造出租出借转让执照、超范围使用频率、盗用或违法使用呼号等行为，无线电管理机构可给予警告、罚款、没收设备、吊销执照等处罚；构成犯罪的依法追究刑事责任。")
    ]

    /// 根据文本检索最相关的知识要点
    static func search(_ text: String, limit: Int = 4) -> [KnowledgeEntry] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let queryGrams = TextSimilarity.bigrams(query)
        var scored: [(KnowledgeEntry, Int)] = []

        for entry in all {
            var score = 0
            for keyword in entry.keywords where query.contains(keyword) {
                score += 6
            }
            if query.contains(entry.title) { score += 8 }

            let corpus = entry.title + entry.keywords.joined() + entry.content
            score += queryGrams.intersection(TextSimilarity.bigrams(corpus)).count

            if score > 0 { scored.append((entry, score)) }
        }

        scored.sort { $0.1 > $1.1 }
        return scored.prefix(limit).map { $0.0 }
    }

    /// 为某道题检索相关知识
    static func search(for question: Question, limit: Int = 3) -> [KnowledgeEntry] {
        search(question.stem + " " + question.options.joined(separator: " "), limit: limit)
    }
}
