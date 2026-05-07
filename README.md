/* ── 강화된 시세 조회 로직 ── */

// 1. 사용할 수 있는 프록시 서버 목록 (Yahoo의 차단을 우회하기 위함)
const PROXY_SERVERS = [
    u => `https://api.allorigins.win/raw?url=${encodeURIComponent(u)}`,
    u => `https://corsproxy.io/?url=${encodeURIComponent(u)}`,
    u => `https://thingproxy.freeboard.io/fetch/${u}`
];

async function fetchPx(code) {
    if (!code) return null;

    // 현재 대시보드에 설정된 조회 기준일 가져오기
    const targetDateStr = document.getElementById('evalDate').value;
    const d = new Date(targetDateStr);
    
    // Yahoo API용 타임스탬프 계산 (충분한 범위를 위해 앞뒤로 여유를 둠)
    const p2 = Math.floor(d.getTime() / 1000) + 86400; 
    const p1 = p2 - (15 * 86400); // 최근 15일치 데이터를 가져와서 가장 가까운 날짜 선택

    // 한국 시장 종목을 위해 .KS(코스피)와 .KQ(코스닥) 순차 시도
    const suffixes = ['.KS', '.KQ'];

    for (let sfx of suffixes) {
        const fullCode = code + sfx;
        const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${fullCode}?interval=1d&period1=${p1}&period2=${p2}`;

        // 여러 프록시를 돌면서 성공할 때까지 시도
        for (let getProxy of PROXY_SERVERS) {
            try {
                const response = await fetch(getProxy(yahooUrl));
                if (!response.ok) continue;

                const data = await response.json();
                const result = data.chart?.result?.[0];
                
                if (result && result.indicators?.quote?.[0]) {
                    const quotes = result.indicators.quote[0];
                    const closes = quotes.close.filter(v => v !== null && v > 0);
                    
                    if (closes.length > 0) {
                        return {
                            today: closes[closes.length - 1], // 기준일(혹은 가장 최근일) 종가
                            prev: closes.length > 1 ? closes[closes.length - 2] : closes[0], // 직전 거래일 종가
                            src: 'CloudAPI'
                        };
                    }
                }
            } catch (e) {
                console.log(`${fullCode} 조회 시도 중 오류 발생, 다음 프록시 시도...`);
            }
        }
    }
    return null;
}

// 2. 버튼 클릭 시 호출되는 메인 함수 (병렬 처리 최적화)
async function loadAllPrices() {
    // 현재 보유 중인 종목 코드(숫자 6자리) 추출
    const codes = [...new Set(Object.entries(pos)
        .filter(([k, p]) => p.qty > 0)
        .map(([k]) => {
            const ticker = k.split('|')[3].split('__')[0];
            return ticker;
        })
        .filter(c => c && c.length === 6))];

    if (codes.length === 0) {
        alert("조회할 보유 종목이 없습니다.");
        return;
    }

    const st = document.getElementById('priceStatus');
    const ds = document.getElementById('hdrDate').value;
    
    showLoading('🚀 실시간 시세 엔진 가동 중...', `대상: ${codes.length}개 종목`, 0);
    st.textContent = `⏳ ${ds} 시세 데이터 수집 중...`;

    let done = 0;
    let ok = 0;

    // 브라우저 과부하 및 차단 방지를 위해 3개씩 묶어서 처리
    const BATCH_SIZE = 3;
    for (let i = 0; i < codes.length; i += BATCH_SIZE) {
        const batch = codes.slice(i, i + BATCH_SIZE);
        const results = await Promise.all(batch.map(c => fetchPx(c)));

        results.forEach((r, idx) => {
            done++;
            if (r) {
                // 원본 코드의 priceMap 구조에 맞게 저장
                priceMap[batch[idx]] = r;
                ok++;
            }
        });

        const pct = Math.round((done / codes.length) * 100);
        updateLoading('데이터 분석 및 반영 중...', `${done}/${codes.length} 종목 처리 완료`, pct);
    }

    hideLoading();
    const now = new Date().toLocaleTimeString('ko-KR');
    if (ok > 0) {
        st.innerHTML = `✅ 시세 반영 완료: ${ok}/${codes.length} (수신시간: ${now})`;
        savePricesToStorage(); // 브라우저 로컬 저장소에 저장
        updEval();    // 상단 통계 갱신
        renderPos();  // 하단 리스트 갱신
    } else {
        st.innerHTML = `❌ 시세 수신 실패. 네트워크 상태나 프록시 제한을 확인하세요.`;
    }
}
