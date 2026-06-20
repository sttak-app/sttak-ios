import Foundation

/// 프로토타입 데이터를 이식한 정적 fixture 모음.
/// 출처: `sttak-data.js`(뉴스·시세·챗봇), `sttak Prototype.dc.html`(종목 리스트),
///       `sttak 퀴즈.dc.html`(퀴즈), `sttak 랭킹.dc.html`(랭킹), `sttak 차트학습.dc.html`(캔들 seed).
enum MockData {

    // MARK: 상수
    static let initialCash = 10_000_000          // sttak_port 초기 cash
    static let initialPoints = 1_240             // sttak_points 기본값
    static let quizReward = 500_000              // 정답 1문제당 자본금(REWARD)
    static let quizPointsPerCorrect = 50         // 정답 1문제당 포인트

    // MARK: 종목 유니버스 (Prototype 온보딩 리스트, 깨진 항목 제외)
    /// (code, name, market, price, changePercent)
    static let universe: [(code: String, name: String, market: Market, price: Int, change: Double)] = [
        ("005930", "삼성전자", .kospi, 73_400, 2.34),
        ("000660", "SK하이닉스", .kospi, 198_500, 1.12),
        ("035420", "NAVER", .kospi, 215_000, -0.81),
        ("035720", "카카오", .kospi, 47_150, 0.64),
        ("005380", "현대차", .kospi, 248_000, -1.20),
        ("000270", "기아", .kospi, 118_900, 0.42),
        ("373220", "LG에너지솔루션", .kospi, 412_000, -2.05),
        ("207940", "삼성바이오로직스", .kospi, 798_000, 0.38),
        ("068270", "셀트리온", .kospi, 189_300, 1.77),
        ("005490", "POSCO홀딩스", .kospi, 421_500, -0.94),
        ("051910", "LG화학", .kospi, 389_000, -1.33),
        ("006400", "삼성SDI", .kospi, 398_500, 0.51),
        ("105560", "KB금융", .kospi, 76_200, 1.04),
        ("055550", "신한지주", .kospi, 48_950, 0.20),
        ("035900", "JYP Ent.", .kosdaq, 68_400, 3.11),
        ("041510", "에스엠", .kosdaq, 91_200, 1.45),
        ("247540", "에코프로비엠", .kosdaq, 178_400, -2.66),
        ("086520", "에코프로", .kosdaq, 92_300, -1.90),
        ("028300", "HLB", .kosdaq, 0, 0),
        ("022100", "포스코DX", .kosdaq, 0, 0),
        ("066970", "엘앤에프", .kosdaq, 0, 0),
        ("293490", "카카오게임즈", .kosdaq, 0, 0),
        ("263750", "펄어비스", .kosdaq, 0, 0),
        ("112040", "위메이드", .kosdaq, 0, 0),
        ("036570", "엔씨소프트", .kospi, 0, 0),
        ("259960", "크래프톤", .kospi, 0, 0),
        ("352820", "하이브", .kospi, 0, 0),
        ("017670", "SK텔레콤", .kospi, 0, 0),
        ("030200", "KT", .kospi, 0, 0),
        ("015760", "한국전력", .kospi, 0, 0),
        ("009150", "삼성전기", .kospi, 0, 0),
        ("012330", "현대모비스", .kospi, 0, 0),
        ("003670", "포스코퓨처엠", .kospi, 0, 0),
        ("096770", "SK이노베이션", .kospi, 0, 0),
        ("034730", "SK", .kospi, 0, 0),
        ("003550", "LG", .kospi, 0, 0),
        ("066570", "LG전자", .kospi, 0, 0),
        ("032830", "삼성생명", .kospi, 0, 0),
        ("316140", "우리금융지주", .kospi, 0, 0),
        ("138040", "메리츠금융지주", .kospi, 0, 0),
        ("000810", "삼성화재", .kospi, 0, 0),
        ("010130", "고려아연", .kospi, 0, 0),
        ("011200", "HMM", .kospi, 0, 0),
        ("009540", "HD한국조선해양", .kospi, 0, 0),
        ("329180", "HD현대중공업", .kospi, 0, 0),
        ("042700", "한미반도체", .kospi, 0, 0),
        ("196170", "알테오젠", .kosdaq, 0, 0),
        ("145020", "휴젤", .kosdaq, 0, 0),
        ("240810", "원익IPS", .kosdaq, 0, 0),
    ]

    static let stocks: [Stock] = universe.map {
        Stock(code: $0.code, name: $0.name, sector: sector(for: $0.code), market: $0.market, currency: .krw)
    }

    /// 인기 종목 10(핸드오프 popularCodes 순서).
    static let popularCodes = ["005930", "000660", "035420", "035720", "005380", "000270", "373220", "207940", "068270", "005490"]

    /// 시세 오버라이드 — sttak-data.js 정본(가격·등락·스파크). 나머지는 universe 값 사용.
    /// (code: price, change, sparkline)
    static let quoteOverrides: [String: (price: Int, change: Double, spark: [Double])] = [
        "005930": (71_200, 1.78, [68, 67, 69, 70, 69, 71, 70, 72, 71, 73, 72, 71.2]),
        "000660": (198_500, 1.12, [188, 190, 189, 192, 195, 193, 196, 197, 196, 199, 198, 198.5]),
        "035420": (215_000, -0.81, [219, 218, 217, 218, 216, 215, 216, 214, 215, 213, 214, 215]),
    ]

    /// 종목 기초 정보 — `sttak 차트학습.dc.html` stocks 배열. (code: 시총, PER, PBR)
    static let fundamentals: [String: StockFundamentals] = [
        "005930": StockFundamentals(marketCap: "424조", per: "14.2배", pbr: "1.4배"),
        "000660": StockFundamentals(marketCap: "144조", per: "9.1배", pbr: "1.8배"),
        "035420": StockFundamentals(marketCap: "35조", per: "21.4배", pbr: "1.2배"),
        "035720": StockFundamentals(marketCap: "21조", per: "38.0배", pbr: "1.5배"),
        "005380": StockFundamentals(marketCap: "52조", per: "5.1배", pbr: "0.6배"),
    ]

    /// 캔들 생성 시드 — `sttak 차트학습.dc.html` stocks 배열. (code: seed, base, finalPrice)
    static let candleSeeds: [String: (seed: Int, base: Double, price: Double)] = [
        "005930": (7, 60_000, 71_200),
        "000660": (13, 170_000, 198_500),
        "035420": (21, 225_000, 215_000),
        "035720": (29, 52_000, 47_150),
        "005380": (37, 240_000, 248_000),
    ]

    // MARK: 챗봇 (sttak-data.js QUICK / FREE_ANSWER)
    static let quickAnswers: [(question: String, answer: String)] = [
        ("이게 왜 중요한가요?", "'잠정실적'은 정식 발표 전에 미리 나오는 숫자라, 시장이 가장 먼저 반응하는 신호예요. 특히 시장 기대치(컨센서스)보다 좋게 나오면 주가가 오르고, 못 미치면 내리는 경우가 많아요. 그래서 '얼마를 벌었나'보다 '기대보다 좋았나'를 보는 게 중요해요."),
        ("주가에 어떤 영향이 있나요?", "발표 전까지는 기대감으로 움직이는 경우가 많아요. 잠정치가 컨센서스를 웃돌면 단기 상승, 밑돌면 하락으로 이어지기 쉽습니다. 다만 이미 주가에 기대가 반영돼 있으면 좋은 숫자에도 차익실현이 나올 수 있어요. 발표 직후 변동성이 커질 수 있다는 점을 기억하세요."),
        ("어려운 말 없이 설명해줘", "쉽게 말하면, 회사가 시험 점수를 공식 발표하기 전에 '이 정도 받았어요'라고 미리 귀띔하는 거예요. 친구들이 예상한 점수보다 잘 봤으면 분위기가 좋아지고, 못 봤으면 실망하는 것과 비슷해요. 그래서 점수 자체보다 '예상보다 잘 봤는지'가 더 중요하답니다."),
    ]

    static let freeAnswer = "좋은 질문이에요. 이 뉴스는 삼성전자의 분기 실적 '예고' 단계라, 아직 방향이 확정되진 않았어요. 핵심은 발표될 숫자가 시장 기대치보다 좋은지인데, 메모리 업황과 파운드리 수주 흐름을 함께 보면 도움이 돼요. 더 구체적으로 궁금한 부분을 짚어 주시면 근거와 함께 설명해 드릴게요."

    // MARK: 퀴즈 (sttak 퀴즈.dc.html QUIZ)
    static let quizQuestions: [QuizQuestion] = [
        QuizQuestion(
            question: "골든크로스(golden cross)가 나타났다는 것은 보통 무엇을 뜻할까요?",
            options: [
                "단기 이동평균선이 장기선을 아래에서 위로 뚫고 올라간 상태",
                "거래량이 갑자기 0으로 줄어든 상태",
                "외국인이 전량 매도하는 구간",
                "배당락일이 지났다는 신호",
            ],
            answerIndex: 0,
            explanation: "단기 이동평균선이 장기 이동평균선을 위로 돌파하는 것을 골든크로스라고 해요. 상승 추세 전환의 신호로 읽히지만, 항상 상승을 보장하지는 않아요.",
            category: "차트 · 지표"
        ),
        QuizQuestion(
            question: "PER(주가수익비율)이 같은 업종 평균보다 낮다면 일반적으로 어떻게 해석할 수 있을까요?",
            options: [
                "이익 대비 주가가 저평가됐을 가능성이 있다",
                "회사가 곧 상장폐지된다는 뜻",
                "배당을 한 푼도 주지 않는다는 뜻",
                "거래가 정지됐다는 뜻",
            ],
            answerIndex: 0,
            explanation: "PER은 주가를 주당순이익으로 나눈 값이에요. 업종 평균보다 낮으면 이익 대비 저평가일 수 있지만, 업종·성장성과 함께 봐야 의미가 있어요.",
            category: "가치 평가"
        ),
        QuizQuestion(
            question: "여러 종목·자산에 나눠 투자하는 \"분산투자\"의 가장 큰 목적은 무엇일까요?",
            options: [
                "한 곳에 쏠린 위험을 여러 자산으로 나눠 낮추기 위해",
                "수익을 무조건 두 배로 만들기 위해",
                "세금을 면제받기 위해",
                "거래 수수료를 없애기 위해",
            ],
            answerIndex: 0,
            explanation: "\"달걀을 한 바구니에 담지 말라\"는 말처럼, 분산투자는 한 종목이 흔들려도 전체 손실을 줄여 변동성과 위험을 낮추는 것이 핵심이에요.",
            category: "투자 원칙"
        ),
    ]

    // MARK: 랭킹 (sttak 랭킹.dc.html)
    static let rankingNames = ["우상향중", "복리요정", "존버의신", "가치투자가", "차트마스터", "꾸준왕", "배당모으기", "분할매수러", "퀀트입문", "월급방어전", "단타졸업생", "관심종목왕"]
    static let rankingChanges = [1, -1, 2, 0, 1, -2, 3, 0, 1, -1, 2, 0]
    static let rankingAssetTop = [16_420_000, 15_880_000, 15_210_000, 14_760_000, 14_300_000, 13_950_000, 13_510_000, 13_200_000, 12_940_000, 12_610_000, 12_330_000, 12_080_000]
    static let rankingPointTop = [9_240, 8_710, 8_330, 7_950, 7_420, 7_010, 6_680, 6_240, 5_870, 5_510, 5_180, 4_920]

    /// 포인트 → 리그 임계값. (브론즈 0–500, 실버 500–1000, 골드 1000–2000, 플래티넘 2000–3500, 다이아 3500+)
    static func league(forPoints points: Int) -> League {
        switch points {
        case ..<500: return .bronze
        case ..<1_000: return .silver
        case ..<2_000: return .gold
        case ..<3_500: return .platinum
        default: return .diamond
        }
    }

    // MARK: 내부 — 섹터(뉴스 보유 종목만 핸드오프에 명시, 나머지는 빈 문자열)
    private static func sector(for code: String) -> String {
        switch code {
        case "005930", "000660": return "반도체"
        case "035420", "035720": return "인터넷"
        default: return ""
        }
    }
}
