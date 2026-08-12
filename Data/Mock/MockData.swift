import Foundation

/// 프로토타입 데이터를 이식한 정적 fixture 모음.
/// 출처: `sttak-data.js`(뉴스·시세·챗봇), `sttak Prototype.dc.html`(종목 리스트),
///       `sttak 퀴즈.dc.html`(퀴즈), `sttak 랭킹.dc.html`(랭킹), `sttak 차트학습.dc.html`(캔들 seed).
enum MockData {

    // MARK: 상수
    static let initialCash = 10_000_000          // 초기 모의투자 자본금(단일 통화)

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

    // 공용(자유) 챗봇 — 일반 학습 도우미. 초보 눈높이 쉬운 설명.
    static let freeChatGreeting = "주식·투자 용어, 차트 보는 법, 뉴스 해석까지 — 무엇이든 편하게 물어보세요. 초보 눈높이로 쉽게 설명해 드릴게요."
    static let freeQuickAnswers: [(question: String, answer: String)] = [
        ("주식 처음인데 뭐부터 볼까요?", "처음엔 '내가 아는 회사'부터 시작하는 게 좋아요. 그 회사가 뭘 팔아서 돈을 버는지, 요즘 실적이 좋아지는지 나빠지는지를 먼저 보세요. 숫자(PER·PBR)는 그다음에 천천히 익혀도 충분해요. 한 번에 다 알려고 하지 말고, 모의투자로 작게 연습해 보는 걸 추천해요."),
        ("PER이 뭐예요?", "PER은 '지금 주가가 회사가 버는 이익에 비해 비싼가'를 보는 지표예요. 쉽게 말하면 이익 한 단위를 사는 데 몇 배를 내는지죠. 같은 업종끼리 비교했을 때 PER이 낮으면 상대적으로 싸게 평가됐을 수 있어요. 다만 낮다고 무조건 좋은 건 아니라, 왜 낮은지 이유도 함께 봐야 해요."),
        ("분산투자는 왜 하나요?", "'달걀을 한 바구니에 담지 말라'는 말과 같아요. 한 종목에 몰아넣으면 그 회사가 흔들릴 때 손실이 커지죠. 여러 종목·자산에 나눠 담으면 하나가 내려도 다른 게 받쳐 줘서 전체 변동성과 위험이 줄어들어요."),
    ]
    static let freeChatFallback = "좋은 질문이에요. 핵심만 짚어 드리면, 투자 판단은 '이 회사가 돈을 잘 벌고 있는지'와 '지금 가격이 그에 비해 합리적인지'를 함께 보는 거예요. 더 구체적인 종목이나 상황을 알려 주시면 근거와 함께 쉽게 설명해 드릴게요."

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

    // MARK: 랭킹 — 보유 자산 단일 리더보드 (제품 결정: 포인트 랭킹·League 미사용)
    static let rankingNames = ["우상향중", "복리요정", "존버의신", "가치투자가", "차트마스터", "꾸준왕", "배당모으기", "분할매수러", "퀀트입문", "월급방어전", "단타졸업생", "관심종목왕"]
    static let rankingChanges = [1, -1, 2, 0, 1, -2, 3, 0, 1, -1, 2, 0]
    static let rankingAssetTop = [16_420_000, 15_880_000, 15_210_000, 14_760_000, 14_300_000, 13_950_000, 13_510_000, 13_200_000, 12_940_000, 12_610_000, 12_330_000, 12_080_000]

    // MARK: 마이 시드 — "이미 써 온 사용자" 초기 상태(보유·매매기록·회고). 거래/평단/현금 정합.
    // 매수 삼성15@67,800 + NAVER4@225,000 + SK3@195,000, 매도 NAVER4@221,000(손실)·삼성5@71,200(부분익절)
    // → 잔여 삼성10@67,800·SK3@195,000, 현금 8,738,000.
    static let seedCash = 8_738_000

    static let seedHoldings: [Holding] = [
        Holding(stockCode: "005930", quantity: 10, averagePrice: .krw(67_800)),
        Holding(stockCode: "000660", quantity: 3, averagePrice: .krw(195_000)),
    ]

    static var seedTrades: [Trade] {
        func daysAgo(_ d: Int) -> Date { Date(timeIntervalSinceNow: -Double(d) * 86_400) }
        let naverRetro = Retrospective(
            id: "retro-naver", summaryLine: "4주 · 221,000원에 매도",
            goodPoints: ["손실을 키우지 않고 정리한 것도 하나의 선택이에요.", "근거를 남겨 다음 판단의 기준을 만들었어요."],
            watchPoints: ["매도 전 거래량 흐름도 함께 봤다면 더 단단했을 거예요."],
            isPartialSell: false, createdAt: daysAgo(34), followUp: nil
        )
        let samsungRetro = Retrospective(
            id: "retro-samsung", summaryLine: "5주 · 71,200원에 매도",
            goodPoints: ["매매 전에 이유를 적어 둔 점이 좋아요. 감이 아니라 신호를 근거로 삼았어요.", "목표 수익에서 일부를 정리해 이익을 지켰어요."],
            watchPoints: ["절반만 정리했어요. 남은 수량의 계획도 함께 세워 두면 좋아요."],
            isPartialSell: true, createdAt: daysAgo(3), followUp: nil
        )
        // 시드는 모두 과거 체결 완료 건. 접수 모델의 필드(status/tradingDate/fillBasis)를 채워 준다.
        func filled(_ id: String, _ type: TradeType, _ code: String, _ qty: Int, _ price: Int,
                    _ rationale: String, _ at: Date, realized: Int?, retro: Retrospective?) -> Trade {
            Trade(
                id: id, type: type, stockCode: code, quantity: qty,
                rationale: TradeRationale(text: rationale),
                status: .filled, orderedAt: at, tradingDate: at,
                fillBasis: type == .buy ? .open : .close,
                referencePrice: .krw(price), filledPrice: .krw(price), filledAt: at,
                rejectedReason: nil, realizedProfit: realized.map(Money.krw), retrospective: retro
            )
        }
        return [
            filled("seed-0", .buy, "005930", 15, 67_800, "실적 기대와 이동평균선 정배열로 분할 매수.", daysAgo(40), realized: nil, retro: nil),
            filled("seed-1", .buy, "035420", 4, 225_000, "AI 검색 베타 기대감에 소량 매수해 봤어요.", daysAgo(38), realized: nil, retro: nil),
            filled("seed-2", .sell, "035420", 4, 221_000, "광고 매출 둔화 우려로 흐름이 꺾이는 것 같아 정리했어요.", daysAgo(34), realized: -16_000, retro: naverRetro),
            filled("seed-3", .buy, "000660", 3, 195_000, "HBM4 양산 호재가 실적으로 이어질 것 같아서.", daysAgo(6), realized: nil, retro: nil),
            filled("seed-4", .sell, "005930", 5, 71_200, "골든크로스 뒤 목표 수익에 도달해서 절반만 정리했어요.", daysAgo(3), realized: 17_000, retro: samsungRetro),
        ]
    }

    // MARK: 매매 근거 프리셋 (GET /reason-templates 의 Mock 대응)
    static let buyReasonTemplates = ["뉴스 호재가 실적으로 이어질 것 같아서", "차트가 골든크로스라 상승 전환 기대", "거래량이 늘어 관심이 가서"]
    static let sellReasonTemplates = ["목표한 수익에 도달해서", "흐름이 꺾이는 것 같아서", "다른 종목에 투자하려고"]

    // MARK: 내부 — 섹터(뉴스 보유 종목만 핸드오프에 명시, 나머지는 빈 문자열)
    private static func sector(for code: String) -> String {
        switch code {
        case "005930", "000660": return "반도체"
        case "035420", "035720": return "인터넷"
        default: return ""
        }
    }
}
