"""0.3 아이템의 번역과 시각 계약을 함께 생성한다. 기존 ID/이름은 보전한다."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game/data"
# 각 행은 기본, 숲, 사막, 묘지, 늪, 설산, 화산, 유물 순서다.
FAMILIES = {
    "sword": [0, 1, 2, 3, 4, 5, 6, 29],
    "bow": [7, 17, 30, 31, 32, 21, 33, 34],
    "staff": [8, 35, 18, 36, 37, 38, 39, 40],
    "spear": [9, 41, 42, 43, 20, 44, 45, 46],
    "mace": [10, 47, 48, 19, 49, 50, 22, 51],
    "armor": [11, 52, 53, 54, 55, 27, 56, 57],
    "shield": [12, 58, 59, 60, 61, 62, 28, 63],
    "boots": [13, 23, 64, 65, 66, 67, 68, 69],
    "helmet": [14, 70, 71, 25, 72, 73, 74, 75],
    "ring": [15, 76, 24, 77, 78, 79, 80, 81],
    "necklace": [16, 82, 83, 84, 26, 85, 86, 87],
}
NAMES = {
    "sword": ["고철검", "가시갈퀴검", "유리톱날", "종추검", "갈대낫", "서리톱", "도가니칼", "별바퀴 장검"],
    "bow": ["빨랫줄 활", "솔가지 사냥활", "모래시계 장궁", "종줄 단궁", "수련잎 접궁", "서릿결 겹활", "풀무 도르래활", "혜성궤도 활"],
    "staff": ["전구 지팡이", "도토리 등불봉", "유리해 지팡이", "촛대 장송봉", "수문 수련봉", "고드름 지휘봉", "용광로 송풍봉", "천구 나침반봉"],
    "spear": ["쇠갈퀴창", "솔방울 갈래창", "유리전갈 꼬리창", "묘비 깃창", "물안개 갈대창", "산양뿔 얼음창", "굴뚝 송곳창", "여울지기 삼지창"],
    "mace": ["너트 철퇴", "참나무 도토리망치", "유리모래 절구", "장송의 종철퇴", "수문 톱니철퇴", "빙하 추망치", "잿불 모루망치", "진동추 기관망치"],
    "armor": ["양철 앞치마", "솔껍질 덧갑옷", "황동 차양흉갑", "묘비 서약갑옷", "수문 비늘갑옷", "덧기운 설산 갑옷", "도가니 방열흉갑", "구동심장 흉갑"],
    "shield": ["솥뚜껑 방패", "솔방울 원방패", "황동전갈 연방패", "장송 십자방패", "수문 반달방패", "서리결 육각방패", "용재 방패", "바퀴살 수호방패"],
    "boots": ["덧댄 작업화", "솔잎 길잡이 신발", "모래돛 장화", "종소리 순례화", "갈대 부유장화", "고드름 등반화", "잿불 풀무신", "회전축 여행화"],
    "helmet": ["주전자 투구", "도토리 순찰투구", "황동 차양관", "종지기의 투구", "수련 수문투구", "산양뿔 방한투구", "굴뚝 용접투구", "별눈 관측투구"],
    "ring": ["철사 반지", "솔방울 매듭반지", "황동전갈 반지", "장송 인장반지", "거머리 고리반지", "눈꽃 육각반지", "불씨 도가니반지", "심장박동 반지"],
    "necklace": ["도르래 목걸이", "도토리 호루라기", "모래시계 목걸이", "작은 장송종", "수련씨 목걸이", "눈물고드름 목걸이", "풀무심장 목걸이", "여섯길 나침반"],
}
# 실루엣 이름과 읽히는 장식. 색상만 바꾼 중복 모델을 만들지 않는다.
VISUALS = {
    "sword": [
        ("notched_cleaver", "asymmetric iron signboard blade with two chips and wrapped grip"),
        ("thorn_hook", "three backward hooks along a curved green blade"),
        ("glass_saw", "wide transparent amber blade with five triangular saw teeth"),
        ("bell_counterweight", "straight blade and a hanging bronze bell pommel"),
        ("reed_sickle", "long thin crescent sickle blade with forked reed guard"),
        ("frost_saw", "blue split-tip blade with a serrated ice ridge"),
        ("crucible_falchion", "heavy red single-edged blade with a square furnace vent"),
        ("starwheel_longsword", "long narrow blade intersected by a six-spoke brass starwheel guard"),
    ],
    "bow": [
        ("laundry_flatbow", "uneven wooden stave with rope knots and a cloth pennant"),
        ("pine_recurve", "recurved branching limbs and a pinecone grip"),
        ("hourglass_longbow", "tall angular double limbs around a brass hourglass"),
        ("bell_shortbow", "short compact square arms with two dangling bells"),
        ("lily_foldingbow", "broad leaf-shaped folding arms and a round lily hub"),
        ("frost_compound", "layered blue hooked limbs with hexagonal ice tips"),
        ("bellows_pulleybow", "split metal arms with large pulley wheels and red bellows"),
        ("comet_orbitbow", "open circular orbit frame with a comet point at its upper tip"),
    ],
    "staff": [
        ("lightbulb_crook", "crooked copper pipe topped by one large bare lightbulb"),
        ("acorn_lantern", "forked branch cradling a hanging ribbed acorn lantern"),
        ("glass_sun", "brass sun disk with seven glass rays above a straight rod"),
        ("funeral_candelabrum", "three uneven candle arms above a dark tapered staff"),
        ("lily_sluice", "open flower bowl above a short horizontal waterwheel"),
        ("icicle_baton", "long tapered crystal spear with two offset floating ice fins"),
        ("furnace_blower", "cage-shaped furnace head with three flared exhaust pipes"),
        ("armillary_compass", "three intersecting brass orbits enclosing a luminous compass needle"),
    ],
    "spear": [
        ("fork_rake", "three crooked iron rake prongs on a long wooden shaft"),
        ("pine_fork", "two spreading hooked branch points with an acorn socket"),
        ("scorpion_tail", "segmented curved brass stinger and two glass side barbs"),
        ("tomb_banner", "broad gravestone-shaped point with a torn side banner"),
        ("reed_lance", "slender leaf-shaped blade tied to a bundled reed shaft"),
        ("goat_horn_pike", "twin swept goat horns embracing a long central ice point"),
        ("chimney_awl", "square perforated chimney socket and a glowing narrow awl"),
        ("ford_trident", "large open crescent trident with a miniature waterwheel center"),
    ],
    "mace": [
        ("hex_nut_club", "oversized hollow hex nut mounted across a short iron handle"),
        ("acorn_mallet", "large ribbed wooden acorn head with a brass band"),
        ("glass_mortar", "hollow square mortar head filled with amber glass shards"),
        ("funeral_bell", "large flared bronze bell hanging sideways from a black handle"),
        ("sluice_cog", "wide eight-tooth gear with two opposed metal jaws"),
        ("glacier_pendulum", "long tapered hexagonal ice weight suspended by a rigid yoke"),
        ("ember_anvil", "heavy asymmetric anvil head with a red hot central groove"),
        ("oscillator_hammer", "paired counterweights around a small piston on a long steel haft"),
    ],
    "armor": [
        ("tin_apron", "square riveted tin apron with a leather neck loop and cloth skirt"),
        ("bark_lamellar", "overlapping bark scales and a raised pinecone shoulder"),
        ("sunshade_breastplate", "arched brass sunshade shoulder with a ventilated narrow chest"),
        ("tomb_oathplate", "tall gravestone chest plate with a cross brace and torn black sash"),
        ("sluice_scalemail", "three overlapping crescent watergate plates with green straps"),
        ("patched_parka", "thick fur collar and asymmetric blue stitched quilted panels"),
        ("crucible_heatplate", "round crucible chest bowl with two broad furnace shoulder shields"),
        ("engine_heartplate", "open ribbed chest cage around a glowing heart-shaped piston"),
    ],
    "shield": [
        ("pot_lid", "round dented pot lid with a central knob and one chipped rim"),
        ("pinecone_buckler", "small round layered pinecone shield with a branch rim"),
        ("scorpion_kite", "elongated pointed kite shield with two raised pincer wings"),
        ("funeral_cross", "wide cross-shaped iron shield with four bell-cut corners"),
        ("sluice_crescent", "open crescent watergate shield with a horizontal rivet bar"),
        ("frost_hexagon", "wide translucent six-sided ice plate with three inset ribs"),
        ("slag_tower", "tall asymmetrical slag slab with a glowing furnace slit"),
        ("wheel_spoke_guard", "large eight-spoke wheel with an offset brass hub and armored rim"),
    ],
    "boots": [
        ("patched_workboots", "short square-toed leather work boots with mismatched tin patches"),
        ("pineleaf_runners", "pointed green ankle boots with swept pineleaf cuffs"),
        ("sand_sail_boots", "tall tan boots with broad triangular side sail flaps"),
        ("bell_pilgrim_shoes", "low curled black shoes carrying small heel bells"),
        ("reed_floatboots", "wide flat reed-pontoon soles and open laced calves"),
        ("icicle_crampons", "thick fur cuffs and four long angular crampon spikes"),
        ("ember_bellows_shoes", "ribbed bellows heels with short metal exhaust nozzles"),
        ("axle_walking_boots", "segmented brass ankle braces with large circular outer bearings"),
    ],
    "helmet": [
        ("kettle_helm", "upturned dented kettle with a curved spout and loop handle"),
        ("acorn_watchcap", "deep ridged acorn cap with a single short stalk crest"),
        ("brass_sunhat", "very broad flat brass brim and a low domed vented crown"),
        ("bellkeeper_helm", "flared bell-shaped helmet with two vertical eye slits"),
        ("lily_gate_helm", "open lily petals around a watergate-bar face guard"),
        ("horned_fur_helm", "thick white fur cap with two short swept goat horns"),
        ("chimney_welder", "box-shaped welding mask and a short crooked exhaust chimney"),
        ("star_lens_helm", "round brass observatory dome with a large offset telescope lens"),
    ],
    "ring": [
        ("wire_loop", "uneven double wire loop with a twisted overlap"),
        ("pine_knot_ring", "braided wooden band with a raised seed-shaped knot"),
        ("scorpion_ring", "open segmented brass ring whose claw and tail meet above the finger"),
        ("funeral_signet", "flat octagonal dark signet with a tiny bell engraving"),
        ("leech_coil_ring", "thick coiled leech body ending in a red sucker gem"),
        ("snowflake_ring", "thin silver band supporting a large branching six-point snowflake"),
        ("ember_crucible_ring", "wide black band supporting a small open red crucible cup"),
        ("heartbeat_ring", "split double band framing a red mechanical heart and two tiny pipes"),
    ],
    "necklace": [
        ("pulley_pendant", "one large rusty grooved pulley hanging on an uneven rope loop"),
        ("acorn_whistle", "small pierced wooden acorn whistle with a leaf on its cord"),
        ("hourglass_pendant", "narrow hourglass in a brass triangular cage"),
        ("funeral_chime", "small flared bronze bell suspended from a black chain"),
        ("lily_seed_pendant", "round green seedpod with five open petals on a reed cord"),
        ("icicle_teardrop", "long blue teardrop crystal with a jagged silver cap"),
        ("bellows_heart", "ribbed red bellows heart with two copper valves"),
        ("sixroad_compass", "large open six-spoke compass dial with a moving central needle"),
    ],
}
ROLES = {
    "sword": ["기본 공격과 방패를 함께 쓰는 균형형", "위력은 유지하고 치명타를 높이는 숲 검", "톱니로 기본 공격 위력을 높인 검", "치명타 대신 묵직한 타격을 택한 검", "기본 위력을 줄이고 치명타를 높인 검", "공격과 치명타를 고르게 더한 검", "치명타를 낮추고 공격력을 크게 높인 검", "방패와 함께 기술 범위를 넓히는 유물 검"],
    "bow": ["거리를 벌려 쓰는 기본 양손 활", "공격과 치명타를 함께 높인 사냥활", "느리게 당겨 먼 적에게 강한 화살을 쏘는 장궁", "짧은 사거리와 빠른 연사의 치명타 단궁", "짧게 당기고 치명타를 크게 높이는 가벼운 접궁", "차가운 겹날개로 공격과 치명타를 더한 활", "고속 화살을 쏜 뒤 회복이 느린 도르래활", "기본 투사체가 적 둘을 더 관통하는 유물 활"],
    "staff": ["거리와 충돌이 있는 마력탄을 쏘는 양손 지팡이", "낮은 기본 위력과 높은 치명타의 등불봉", "마력탄 위력을 높인 유리해 지팡이", "치명타를 줄이고 마력탄 위력을 높인 장송봉", "치명타를 더한 가벼운 균형 지팡이", "치명타 중심의 고드름 지팡이", "큰 위력과 낮은 치명타의 송풍봉", "모든 범위 기술 반경을 넓히는 유물 지팡이"],
    "spear": ["먼 적을 찌르는 기본 양손 창", "위력과 치명타를 고르게 더한 갈래창", "단발 위력 중심의 긴 꼬리창", "치명타 중심의 가벼운 깃창", "공격과 치명타를 높인 긴 갈대창", "안정된 위력과 치명타를 지닌 얼음창", "무거운 위력 중심의 송곳창", "넓은 기술 범위와 긴 찌르기를 가진 유물 창"],
    "mace": ["방패와 함께 쓰는 강한 근접 타격 무기", "가벼운 위력과 높은 치명타의 나무망치", "치명타 대신 타격력을 크게 높인 절구", "강한 기본 타격을 위한 장송 철퇴", "위력과 체력을 함께 챙기는 톱니철퇴", "치명타를 더한 균형형 얼음 추망치", "공격력을 크게 높인 무거운 모루망치", "실제 타격 피해로 체력을 회복하는 유물 망치"],
    "armor": ["방어와 최대 체력을 함께 더하는 기본 갑옷", "방어 일부를 최대 체력으로 바꾼 갑옷", "최대 체력 일부를 방어로 바꾼 흉갑", "높은 최대 체력과 낮은 방어의 서약갑옷", "고른 방어와 약간의 이동속도를 더한 갑옷", "방어와 체력을 모두 높인 방한 갑옷", "큰 방어와 낮은 체력의 방열 흉갑", "방어와 체력에 작은 흡혈을 더한 유물 흉갑"],
    "shield": ["검·메이스와 조합하는 기본 방패", "방어 일부를 최대 체력으로 바꾼 원방패", "방어에 작은 치명타를 더한 연방패", "무거운 방어 중심의 십자방패", "방어와 이동속도를 함께 더한 반달방패", "방어와 최대 체력을 고르게 더한 육각방패", "단단한 방어를 더하는 용재 방패", "방어와 기술 반경을 함께 더한 유물 방패"],
    "boots": ["이동속도를 높이는 기본 작업화", "기본 작업화보다 빠른 숲 탐험 신발", "속도 일부를 최대 체력으로 바꾼 장화", "속도와 작은 치명타를 더한 순례화", "빠른 이동 중심의 가벼운 부유장화", "속도 일부를 방어로 바꾼 등반화", "속도와 작은 공격력을 더한 풀무신", "빠른 이동과 작은 기술 범위를 더한 유물 신발"],
    "helmet": ["방어와 최대 체력을 더하는 기본 투구", "낮은 방어와 높은 체력의 순찰투구", "높은 방어와 작은 이동속도의 차양관", "방어와 체력을 높인 종지기 투구", "최대 체력과 치명타를 함께 더한 투구", "방어와 체력의 균형을 잡은 방한투구", "체력 일부를 공격으로 바꾼 용접투구", "기술 반경과 방어를 함께 더한 유물 투구"],
    "ring": ["공격과 치명타를 더하는 기본 반지", "공격 일부를 최대 체력으로 바꾼 반지", "공격과 치명타를 높인 황동 반지", "공격 대신 치명타를 높인 인장반지", "공격과 작은 흡혈을 더한 고리반지", "치명타와 최대 체력을 더한 눈꽃반지", "치명타 대신 공격을 높인 불씨반지", "실제 피해에 비례해 체력을 회복하는 유물 반지"],
    "necklace": ["치명타와 최대 체력을 더하는 기본 목걸이", "체력과 작은 이동속도를 더한 호루라기", "치명타를 높이고 체력을 줄인 목걸이", "치명타 일부를 방어로 바꾼 장송종", "치명타와 체력을 높인 수련씨 목걸이", "체력을 크게 높인 얼음 목걸이", "체력 일부를 공격으로 바꾼 풀무심장", "체력과 넓은 기술 반경을 더한 유물 나침반"],
}
LORE = {
    "sword": ["버려진 간판을 잘라 손잡이에 천을 감았다. 수레마을 첫 원정의 동반자다.", "솔가지의 거꾸로 난 가시를 칼등에 세웠다. 걸어 당기는 갈퀴 모양이 뚜렷하다.", "사막의 깨진 유리 판을 다섯 톱니로 이어 붙였다. 넓은 날이 볕을 가른다.", "무딘 날의 균형을 종 모양 추로 잡았다. 손잡이 끝의 작은 종이 걸음을 알린다.", "갈대 잎처럼 길고 얇게 휜 날이다. 젖은 녹색 끈이 손을 감싼다.", "톱날 사이로 얼음 능선이 자랐다. 갈라진 푸른 끝을 보고 검을 구분한다.", "도가니의 붉은 쇠를 넓은 외날로 폈다. 네모난 통풍구가 칼등을 뚫는다.", "길 잃은 마차의 별바퀴를 손막이로 썼다. 여섯 바퀴살이 기술의 궤적을 펼친다."],
    "bow": ["빨랫줄과 휜 판자로 만든 활이다. 묶인 헝겊 조각이 바람을 보여준다.", "살아 있던 솔가지의 갈래를 그대로 살렸다. 솔방울 손잡이가 손에 걸린다.", "두 개의 긴 황동 날개 사이에 모래시계를 달았다. 느린 모래가 한 발의 무게를 잰다.", "짧고 각진 활의 양 끝에서 작은 종이 매달린다. 오래된 종줄을 시위로 삼았다.", "넓은 수련잎 모양 날개가 중앙 경첩에서 접힌다. 둥근 씨방이 활의 중심이다.", "푸른 뼈대 위에 얼음 날개를 겹쳤다. 육각 얼음 장식이 두 끝을 감싼다.", "풀무의 붉은 가죽과 두 개의 큰 도르래로 시위를 당긴다. 금속 날개가 둘로 갈라진다.", "혜성의 꼬리가 휘어진 고리처럼 이어진 활이다. 밝은 끝의 화살이 적의 줄을 꿰뚫는다."],
    "staff": ["구부러진 구리 수도관 위에 전구 하나를 꽂았다. 깨지지 않은 유리를 아껴 쓴다.", "갈라진 나뭇가지 아래 도토리 등불을 걸었다. 빛은 껍질의 틈으로 샌다.", "황동 태양 둘레에 유리 햇살 일곱 개를 박았다. 사막의 낮을 봉 끝에 붙잡았다.", "길이가 다른 세 촛대가 봉 위에 섰다. 꺼진 초에도 장송의 박자가 남아 있다.", "벌어진 수련 꽃받침 아래 작은 물레를 달았다. 오래된 수문의 축을 재활용했다.", "긴 고드름 옆으로 얼음 날개 두 장이 비켜 선다. 지휘봉처럼 가늘게 쥔다.", "철창 화로와 세 개의 나팔 통풍관을 한데 묶었다. 가운데에 붉은 불씨가 산다.", "세 황동 궤도 안에서 나침반 바늘이 돈다. 서로 다른 길의 마력이 한 점에서 만난다."],
    "spear": ["부러진 쇠갈퀴 세 이빨을 긴 자루에 묶었다. 못 쓰는 농기구도 거리를 만든다.", "갈라진 솔가지 두 끝을 날카롭게 세웠다. 도토리 받침이 날의 흔들림을 잡는다.", "황동 마디를 굽혀 전갈 꼬리 모양으로 이었다. 유리 가시 두 개가 옆을 지킨다.", "묘비처럼 넓고 네모난 창날이다. 찢긴 검은 깃발이 날 아래 매달린다.", "갈대 다발 위에 긴 잎날을 묶었다. 물안개 속에서도 가는 끝이 먼저 보인다.", "굽은 산양뿔 두 개 사이로 긴 얼음 촉이 솟는다. 산등성이의 선을 닮았다.", "네모난 굴뚝에 가는 송곳을 끼웠다. 구멍 사이로 남은 열기가 새어 나온다.", "초승달처럼 열린 세 갈래 창 안에서 작은 수차가 돈다. 여울을 지키던 표지에서 얻었다."],
    "mace": ["큰 육각 너트를 짧은 철자루에 끼웠다. 비어 있는 머리 한가운데로 먼 곳이 보인다.", "줄무늬 도토리 모양 참나무 머리를 황동 띠로 조였다. 껍질의 능선이 타격면이다.", "속이 빈 네모 절구에 유리 파편을 채웠다. 휘두를 때마다 모래가 벽을 친다.", "장송의 큰 종을 검은 손잡이에 가로 달았다. 벌어진 종 입구가 무거운 타격면이 된다.", "여덟 이가 난 수문 톱니 두 끝을 집게처럼 세웠다. 물에 닳은 녹색 쇠다.", "기다란 육각 얼음 추를 단단한 멍에에 매달았다. 좁은 끝에 무게가 모인다.", "한쪽이 길게 튀어나온 모루를 망치머리로 썼다. 가운데 홈에 잿불이 남아 있다.", "서로 반대로 움직이던 추를 작은 피스톤으로 이었다. 남은 진동이 주인의 심장을 돕는다."],
    "armor": ["가죽 목끈에 리벳 박은 양철판을 달았다. 천 앞치마가 무릎까지 이어진다.", "솔껍질 비늘을 여러 겹 포갰다. 한쪽 어깨에는 큰 솔방울 덮개를 얹었다.", "둥근 차양 어깨와 통풍구 많은 좁은 흉갑이다. 사막 햇살을 옆으로 흘린다.", "가슴 앞의 네모난 묘비판을 십자 버팀대로 고정했다. 검은 띠 끝이 찢어졌다.", "반달 모양 수문판 세 장을 녹색 끈으로 겹쳐 묶었다. 진흙물이 흘러내릴 틈을 남겼다.", "두툼한 털깃 아래 푸른 천 조각을 비스듬히 기웠다. 서로 다른 실밥이 오래된 원정을 말한다.", "둥근 도가니 몸체에 넓은 방열 어깨를 붙였다. 뜨거운 쇳가루를 바깥으로 흘린다.", "갈비뼈 같은 철제 틀 안에 심장 모양 피스톤이 뛴다. 전투의 힘을 작은 회복으로 돌린다."],
    "shield": ["찌그러진 솥뚜껑 중앙의 손잡이를 그대로 쥔다. 테두리 한쪽이 깨져 있다.", "솔방울 비늘을 둥글게 모아 솔가지 테두리로 감쌌다. 작은 몸체가 방어를 돕는다.", "끝이 긴 연 모양 판 양옆에 전갈 집게 날개를 세웠다. 황동빛이 볕을 받는다.", "종을 잘라 낸 네 귀퉁이 사이로 큰 십자판이 남았다. 어두운 쇠가 전면을 막는다.", "초승달 수문판에 가로 리벳 막대를 댔다. 벌어진 틈으로 전장을 살핀다.", "투명한 육각 얼음판 안에 은빛 살 세 개가 박혔다. 설산의 결이 넓은 면을 가른다.", "키 큰 용재판 한쪽이 거칠게 찢겼다. 가느다란 붉은 화로 틈이 중앙을 지난다.", "여덟 바퀴살과 두꺼운 테두리를 방패로 삼았다. 중심에서 비킨 황동 축이 기술 궤적을 돌린다."],
    "boots": ["네모난 앞코에 서로 다른 양철 조각을 덧댔다. 닳은 가죽을 다시 꿰맸다.", "끝이 뾰족한 녹색 신발에 솔잎 발목깃을 달았다. 길잡이의 가벼운 걸음이다.", "키 큰 모래색 장화 옆에 삼각 돛 덮개가 펼쳐진다. 사막 모래가 신 안으로 들지 않게 묶는다.", "검은 낮은 신발의 뒤꿈치에서 작은 종이 울린다. 순례길의 낡은 발끝은 위로 굽었다.", "넓고 평평한 갈대 밑창을 노처럼 엮었다. 종아리는 끈으로 열어 가볍게 했다.", "두꺼운 털 발목 아래 긴 얼음발톱 네 개를 달았다. 얼어붙은 비탈을 밟는다.", "주름진 풀무 뒤꿈치와 짧은 배기구가 붙었다. 잿불 작업장의 신발을 고쳐 쓴다.", "황동 발목틀 바깥의 큰 베어링이 걸음을 받친다. 구간마다 다른 금속판이 움직인다."],
    "helmet": ["찌그러진 주전자를 뒤집어 썼다. 굽은 주둥이와 둥근 손잡이가 그대로 남았다.", "깊은 도토리 껍질 위로 짧은 꼭지 하나가 솟는다. 홈이 많은 테두리가 머리를 감싼다.", "낮은 황동 돔 주위에 아주 넓은 챙이 둘렀다. 작은 통풍구가 사막의 열을 뺀다.", "벌어진 종 모양 투구에 눈구멍 두 줄을 냈다. 종지기의 얼굴은 그 뒤에 숨는다.", "열린 수련 꽃잎 사이에 수문 창살 얼굴가리개를 달았다. 물빛 판이 머리를 둘러싼다.", "흰 털모자 위에 뒤로 굽은 짧은 산양뿔 두 개를 붙였다. 푸른 이마판이 차갑다.", "네모 용접면 옆에 비뚤어진 짧은 굴뚝이 솟았다. 어두운 눈창 아래 쇠 덮개가 길다.", "관측소 황동 돔에 큰 망원경 렌즈를 비껴 달았다. 별을 찾던 눈으로 전장의 빈틈을 본다."],
    "ring": ["철사를 두 번 감고 끝을 꼬았다. 고르지 않은 작은 고리가 첫 장신구다.", "나무 줄기를 땋은 띠 위에 씨앗 매듭을 올렸다. 숲의 갈색과 녹색이 겹친다.", "마디진 전갈의 꼬리와 집게가 손등에서 만난다. 가운데는 비어 있는 황동 고리다.", "납작한 팔각 인장에 아주 작은 종을 새겼다. 어두운 면의 홈은 손때로 빛난다.", "굵은 거머리 모양 고리 끝에 붉은 흡반 보석이 붙었다. 물안개에서 찾은 재료다.", "가느다란 은띠 위에 여섯 갈래 눈꽃이 활짝 폈다. 손가락보다 넓은 얼음 가지다.", "넓은 검은 띠 위에 작은 열린 도가니를 얹었다. 안의 붉은 불씨가 꺼지지 않는다.", "갈라진 이중 띠 사이에서 붉은 기계심장이 박동한다. 작은 관 두 개가 힘을 되돌린다."],
    "necklace": ["홈이 깊게 파인 녹슨 도르래 하나를 밧줄에 걸었다. 끊어진 수레에서 구한 물건이다.", "구멍 뚫린 도토리 피리에 작은 잎을 묶었다. 소리는 숲길에서 짧게 멀리 퍼진다.", "가느다란 모래시계를 황동 삼각 틀 안에 넣었다. 낡은 사막길의 시간을 센다.", "작게 벌어진 청동 종 하나가 검은 사슬에 매달린다. 잃어버린 종탑의 울림이다.", "다섯 잎이 열린 씨방을 갈대줄에 걸었다. 둥근 녹색 씨앗이 안쪽에 남았다.", "긴 푸른 눈물 결정 위에 거친 은뚜껑을 씌웠다. 설산 처마에서 찾은 고드름이다.", "붉고 주름진 풀무심장에 구리 밸브 두 개를 달았다. 작지만 단단한 작업실의 부품이다.", "여섯 바퀴살의 열린 나침반 안에서 바늘이 돈다. 돌아올 길을 기억한 주인의 기술을 넓힌다."],
}
# 신규 착용 도안은 기본 능력치 사이의 교환과 작은 부가 능력치로 역할을 나눈다.
MODIFIERS = {
    49: {"max_hp": 0.45},
    52: {"defense": 0.7, "max_hp": 1.5}, 53: {"defense": 1.6, "max_hp": 0.6},
    54: {"defense": 0.65, "max_hp": 1.8}, 55: {"speed": 0.006},
    56: {"defense": 1.9, "max_hp": 0.55}, 57: {"defense": 1.2, "max_hp": 1.3},
    58: {"defense": 0.75, "max_hp": 0.8}, 59: {"defense": 1.0, "crit": 0.12},
    60: {"defense": 1.45}, 61: {"defense": 0.8, "speed": 0.006},
    62: {"defense": 0.95, "max_hp": 0.6}, 63: {"defense": 1.2},
    64: {"speed": 0.8, "max_hp": 0.65}, 65: {"speed": 0.95, "crit": 0.12},
    66: {"speed": 1.3}, 67: {"speed": 0.8, "defense": 0.1},
    68: {"speed": 1.0, "atk": 0.12}, 69: {"speed": 1.3},
    70: {"defense": 0.7, "max_hp": 1.5}, 71: {"defense": 1.6, "max_hp": 0.7, "speed": 0.004},
    72: {"defense": 0.8, "max_hp": 1.1, "crit": 0.12}, 73: {"defense": 1.2, "max_hp": 1.25},
    74: {"max_hp": 0.65, "atk": 0.2}, 75: {"defense": 1.3, "max_hp": 1.1},
    76: {"atk": 0.8, "max_hp": 0.55}, 77: {"atk": 0.6, "crit": 1.6},
    78: {"atk": 1.1, "crit": 0.65}, 79: {"atk": 0.7, "crit": 1.25, "max_hp": 0.5},
    80: {"atk": 1.7, "crit": 0.6}, 81: {"atk": 1.0, "crit": 1.0},
    82: {"crit": 0.7, "speed": 0.006}, 83: {"crit": 1.6, "max_hp": 0.65},
    84: {"crit": 0.65, "max_hp": 1.0, "defense": 0.12}, 85: {"crit": 0.8, "max_hp": 1.6},
    86: {"crit": 0.9, "max_hp": 0.8, "atk": 0.2}, 87: {"crit": 0.9, "max_hp": 1.15},
}
EFFECTS = {29: {"area": 0.12}, 34: {"pierce": 2}, 40: {"area": 0.2},
           46: {"area": 0.12}, 51: {"lifesteal": 0.06}, 57: {"lifesteal": 0.02},
           63: {"area": 0.06}, 69: {"area": 0.04}, 75: {"area": 0.06},
           78: {"lifesteal": 0.02}, 81: {"lifesteal": 0.06}, 87: {"area": 0.12}}
COLORS = ["#859393", "#4e7549", "#bd9250", "#615c70", "#3b8174", "#80b8d2", "#7d4c44", "#b59959"]
ACCENTS = ["#bc8b55", "#b9ad69", "#7de0d4", "#d1ac67", "#b5d689", "#e3f5ff", "#ff813b", "#70e3d3"]
MATERIALS = ["salvaged_iron_leather", "wood_brass", "brass_glass", "aged_iron_bronze", "reed_copper", "ice_fur_silver", "slag_iron_ember", "clockwork_brass_crystal"]
ARTIFACT_REGIONS = {"sword": 0, "bow": 1, "staff": 2, "spear": 3, "mace": 4,
                    "armor": 5, "shield": 0, "boots": 1, "helmet": 2, "ring": 3, "necklace": 4}

def generate():
    items = [None] * 88
    text = {}
    for family_index, (kind, ids) in enumerate(FAMILIES.items()):
        for variant, item_id in enumerate(ids):
            region = -1 if variant == 0 else variant - 1 if variant < 7 else ARTIFACT_REGIONS[kind]
            district = family_index % 5 if variant < 7 else 4
            effect = EFFECTS.get(item_id, {})
            effect_id = next(iter(effect), "")
            shape, feature = VISUALS[kind][variant]
            items[item_id] = {"id": item_id, "kind": kind, "region": region, "district": district,
                              "artifact": variant == 7, "name_key": f"DESIGN_{item_id}",
                              "role_key": f"ROLE_{item_id}", "description_key": f"DESC_{item_id}",
                              "effect_id": effect_id, "effects": effect,
                              "modifiers": MODIFIERS.get(item_id, {}),
                              "visual": {"variant": variant, "shape": shape, "material": MATERIALS[variant],
                                         "color": COLORS[variant], "accent": ACCENTS[variant], "feature": feature}}
            text[f"DESIGN_{item_id}"] = NAMES[kind][variant]
            text[f"DESC_{item_id}"] = LORE[kind][variant]
            text[f"ROLE_{item_id}"] = ROLES[kind][variant]
    assert all(items) and len({x["visual"]["shape"] for x in items}) == 88
    (DATA / "item_catalog.json").write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    translation_path = DATA / "session_ko.tres"
    original = translation_path.read_text(encoding="utf-8-sig")
    original = original[:original.rfind("}")].rstrip()
    if not original.endswith(","):
        original += ","
    text.update({"EFFECT_PIERCE": "기본 투사체가 적 %d명을 추가 관통합니다.",
                 "EFFECT_LIFESTEAL": "실제 가한 피해의 %d%%만큼 체력을 회복합니다.",
                 "EFFECT_AREA": "범위 기술 반경이 %d%% 증가합니다.",
                 "CACHE_EMPTY": "이 보물 지점은 이미 조사했습니다.",
                 "CACHE_OPEN": "숨겨진 보물에서 장비와 코인을 찾았습니다.",
                 "SOURCE_COMMON": "마을 기본 상품 · 모든 지역 공통 드롭",
                 "SOURCE_REGION": "%s · %s 집중 드롭 · 보스 격파 후 주문 가능",
                 "SOURCE_ARTIFACT": "%s · %s 유물 집중 드롭 · 보스 격파 후 주문 가능"})
    text.update({"COMBAT_PROFILE": "준비 %.2f초 · 회복 %.2f초 · 사거리 %.1fm",
                 "COMBAT_PROJECTILE": " · 탄속 %.1fm/s"})
    # 0.2 이름은 보전하고 이 생성기가 소유한 문구만 정확한 키로 갱신한다.
    for key, value in text.items():
        if key.startswith("DESIGN_") and int(key.split("_")[1]) < 29:
            continue
        pattern = re.compile(r'^"' + re.escape(key) + r'": "(?:[^"\\]|\\.)*"(?=,?\s*$)', re.M)
        original = pattern.sub(lambda _: f'{json.dumps(key)}: {json.dumps(value, ensure_ascii=False)}', original)
    additions = [f'{json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}'
                 for k, v in text.items() if f'"{k}"' not in original]
    translation_path.write_text(original + "\n" + ",\n".join(additions) + "\n}\n", encoding="utf-8", newline="\r\n")
    print(f"Generated {len(items)} unique item profiles and {len(additions)} Korean messages.")

if __name__ == "__main__":
    generate()
