# 구현 작업 기록

2026-11-18. Windows에서 실행 가능한 Godot 프로젝트다. 시작 씬은 수레마을이며 마차로 숲에 들어간다. 기획 규칙은 데이터와 저장 세션이 담당하고, 전투·지형·모델·HUD는 실제 게임 씬에서 연결한다. [실행과 조작](README.md)

## 구현한 첫 원정

마차 탑승, 두 갈래 숲길, 3대1 합성, 중간보스 두 번, 고목왕, 귀환 표석, 사막 도착을 새 슬롯에서 키보드·마우스 입력으로 확인했다. 3회 기준 96~125초였으며 이 값은 경로와 적의 위치를 참조해 조작한 자동 플레이 시간이다. 쉬움 일반 적의 감지 거리를 이후에 조정했다. 사람의 초회 소요 시간은 별도 측정 대상이다. [첫 원정 입력 기록](tasks/first_expedition_results.md)

| 기능 | 확인한 범위 |
| --- | --- |
| 기동 | Godot MCP로 시작 씬 생성·스크립트 연결·실행·화면 캡처·종료. 캐시와 MCP 파일을 제외한 복사본을 Godot 4.7.2에서 새로 임포트하고 120프레임 기동했다. 한글 기본 글꼴은 런타임에 설정해 최초 임포트의 글꼴 로딩 오류를 해소했다. |
| 지형과 시설 | 수레마을과 여섯 필드, 필드당 일반 몬스터 후보 40곳, 두 갈래 길과 능선·다리를 구현했다. 충돌 및 서비스 접근 검사 1,814건을 통과했고 실제 플레이어 물리 입력으로 숲의 양쪽 길을 왕복해 40개 경유 지점을 통과했다. |
| 저장·전리품 | 단일 슬롯 2세대 저장과 손상 복구, 동시 실행 쓰기 잠금, 합성 연쇄·장비 보호·창고·상점·의뢰를 검증했다. 세션 검사 1,176건을 통과했다. 한 번의 회오리에서 두 몬스터가 쓰러진 사이 저장 실패가 반복돼도 두 처치가 순서대로 한 번씩 반영됐다. |
| 전투·표현 | 30·60·120 렌더 FPS에서 타격 수와 무적 구간을 검증했다. 주인공 클립 11개와 숲 7종의 클립 49개를 GLB로 이관했다. 8방향 자세·기본 공격·기술 키프레임을 실제 게임 카메라에서 촬영했다. [Blender 원본과 제작 검증](art/blender/README.md) · [공격 자세](art/review/hero_combat.png) |
| 난이도 | 네 난이도와 24노선, 보스 첫 처치 해금과 엔딩 이후 반복을 세션 검사에서 확인했다. 일반 이상에서는 방어·근접형과 원거리·지원형이 가까이 등장하며 여섯 필드에서 배치한 12쌍의 종과 거리를 검증했다. |
| 화면·소리 | 한국어 HUD, 인벤토리, 거래·노선표, 키 재지정·큰 글자·흔들림·섬광 설정을 연결했다. 로컬 생성한 검풍·금속 타격·등장 종·습득음 4개를 동작 신호에 연결했다. WAV는 44.1kHz 스테레오이며 효과 시작점과 감쇠 길이를 조정했다. |

검증 도구는 `game/tests/`와 프로젝트 루트의 `tests/`에 있다. 전체 입력 원정은 임시 슬롯을 사용한다. 고밀도 성능 측정은 전투 인원과 장면을 고정하는 별도 시나리오다. [성능 기록](tasks/performance_results.md)

쉬움 캠페인에서는 한 슬롯으로 숲·사막·묘지·늪·설산·화산의 보스 6체를 차례로 처치하고 마을 마차로 일반 숲에 들어갔다. 여섯 지역의 45종을 실제 씬에서 관찰했다. 이 회차의 설산에서는 자동 입력이 여러 차례 사망했다. 입력 전략과 사람이 체감하는 난이도는 별도로 평가한다. [캠페인 입력 검증](tasks/campaign_input_results.md)

획득한 슬롯을 이어서 일반 숲·사막·묘지까지 총 **9/24노선**의 보스를 실제 입력으로 처치했다. 일반 늪은 첫 시도 후 회피·기술 거리 전략을 바꿔 재도전했으며 12분의 게임 시간 동안 43회 사망했다. 보스 체력은 846 중 23까지 내려갔다. 일반 늪을 포함한 나머지 15개 노선의 입력 완주와 사람 기준 밸런스는 미확인이다. 쉬움 감지 거리 조정 후 별도 새 슬롯에서는 사망 1회, 사막 도착 96.20초였다. [저장과 입력 로그](tasks/evidence/campaign-20261118.zip)

고목왕과의 전투는 검수용 배치에서 1280×720, 30fps로 8.7초간 녹화했다. 실제 피해·공격 예고·모션·HUD·음향이 들어 있으며, 촬영 시 시작 위치와 해금 상태를 지정했다. [전투 영상](art/review/forest_combat.mp4) · [촬영 조건](art/review/forest_combat.md)

지도는 M으로 열고 M 또는 Esc로 닫는다. 실제 길·건물·현재 위치·시설과 보스 방향을 표시한다. 1280×720에서 지도 중 이동·기술 정지, 재개, 150% 글자를 검사했다. 실제 창의 가방·거래·노선표는 800×600에서도 조작을 확인했다. [지도 검사](tests/area_map.gd) · [마을 지도](art/review/map_town.png)

Radeon 780M의 1080p 불지옥 25체 전투에서 예고선 메시 생성을 수정한 후 120초 기준 중앙값 13.410ms, p95 20.938ms를 측정했다. 목표는 p95 16.7ms다. 오디오 재생 중 창을 닫을 때 남던 WAV 참조는 종료 처리 수정 후 별도 검사를 통과했다. [부하 조건과 남은 성능 차이](tasks/performance_results.md)

## 모듈 간 계약

- 메인 씬은 세션, 월드, 플레이어, 몬스터, 화면을 소유한다. 지역 번호는 마을 -1, 필드 0~5, 난이도 0~3이다. 게임 기획서의 테마 순번에서 1을 뺀 내부 번호다.
- `res://scripts/session.gd`는 Node다. `start_slot()`, `world_state(region, difficulty) -> Dictionary`, `can_travel(region,difficulty)`, `record_kill(region,difficulty,kind,spawn_id,pos:Vector3)`, `tick_rest(region,difficulty,seconds:int)`, `pickup(item_id)`, `act(action:String, args:Dictionary) -> bool`, `ui_state() -> Dictionary`를 제공한다. 변경 시 `changed`, 안내 시 `notice(message:String)`를 보낸다. kind는 normal/mini/boss다. world_state는 phase(hunt/mini/boss/rest), trace, minis, cycle, rest, drops 배열을 준다. drop은 id와 pos(Vector3)를 가진다. UI 상태에는 coins, bag, chest, equipped, auto, first_merge, forest_clear, traveler, quests, cleared가 있다. 무기는 id, name, grade(0~6), atk, crit, locked를 가진다.
- `res://scripts/player.gd`는 CharacterBody3D다. `configure(gear:Dictionary,first_merge:bool,forest_clear:bool)`, `take_damage(amount:int)`와 `died`, `health_changed(current:int,maximum:int)`, `cue(kind:String)`를 제공한다. 몬스터 그룹은 enemies, 플레이어 그룹은 player다. 플레이어가 몬스터의 `take_hit(amount:int,pull:Vector3)`를 호출한다. 캐릭터의 카메라는 플레이어가 관리한다.
- `res://scripts/enemy.gd`는 CharacterBody3D다. `setup(region:int,difficulty:int,kind:String,index:int,spawn_id:String)`, `take_hit(amount:int,pull:Vector3)`, `defeated(kind:String,spawn_id:String,pos:Vector3)`, `cue(kind:String)`를 제공한다. 일반 몬스터 종 수는 5/6/5/6/5/6이다.
- `res://scripts/world.gd`는 Node3D다. `build(region:int)`, `entry_point()->Vector3`, `spawn_points()->Array[Vector3]`, `boss_point()->Vector3`, `service_near(pos:Vector3)->String`을 제공한다. 서비스 키는 coach/elder/shop/chest/traveler/return. 월드가 조명·지형·충돌·장식과 마을의 시설을 만든다.
- `res://scripts/hud.gd`는 CanvasLayer다. `refresh(info:Dictionary)`, `open_panel(kind:String)`, `close_panel()`, `panel_open()->bool`, `toast(message:String)`를 제공한다. `command(action:String,args:Dictionary)`를 메인에 보낸다. 메인은 세션 UI 상태에 region,difficulty,hp,max_hp,world,service,unlocked(24개 bool, 난이도×6+지역 순), cooldowns(Q/E/R/회피에 해당하는 hook/spin/slam/dodge 초)를 보탠다. HUD가 게임 일시정지 여부를 메인에 알리고 메인은 물리를 멈춘다.
- 거래 명령은 equip/unequip/lock/store/withdraw/sell/pickup에 id, merge에 ids, auto에 enabled, buy에 vendor(shop/traveler), claim에 quest(0=첫 합성, 1~6=지역), travel에 region/difficulty를 쓴다. 마을 출발·귀환 시 메인은 세션에 depart/return을 전달한다.
- Blender 주인공은 `res://assets/models/hero.glb`로 이관한다. 본·클립 이름은 캐릭터와 제작 담당이 맞춘다. 게임 원본과 생성 도구는 작업 폴더에 보관한다.

## 검증

지역 지도는 지면 제작에 사용한 길 마스크와 실제 서비스 좌표를 표시한다. M을 눌러 보고 닫을 때까지 전투와 시간이 멈춘다.

저장 경합 수정 범위는 같은 로컬 저장 폴더를 두 게임 창이 함께 여는 상황이다. 첫 창은 종료할 때까지 쓰기 권한을 유지하고, 뒤에 연 창은 슬롯을 읽거나 변경하기 전에 안내와 재시도를 제공한다. 별도 폴더의 동시 실행, 첫 창의 계속 저장, 정상 종료와 강제 종료 뒤 재진입을 각각 두 프로세스로 확인한다.

세션의 확률·거래·저장 경계, 물리 판정과 보스 주기, 24노선의 진행을 검증하고 Godot MCP로 실제 창의 이동·메뉴·전투를 확인한다. 실행한 범위와 남은 품질 검증은 이 기록에 갱신한다.

### 몬스터와 예고 판정

첫 숲 원정에서 여러 무리가 동시에 합류한 플레이 기록을 받아 일반 몬스터의 추격 거리를 조정했다. 쉬움 숲에서 솔가시벌은 6.6m, 나머지는 6m 이내에서 추격한다. 일반 난이도 9m, 어려움·불지옥 12.1m, 보스 19m 경계 전후의 추격·복귀·대기를 자동 검증했다.

종별 이름과 수치는 `game/data/monsters_ko.tres`, `game/data/monsters.gd`에 있다. 숲 7종은 Blender 리그와 종별 7개 클립을 사용한다. 나머지 38종은 `monster_model.gd`에서 종별 실루엣을 만들고 다리·꼬리·날개를 움직인다. 사냥·예고·판정·회복은 `enemy.gd`의 물리 시계가 구동한다. `monster_attack.gd`는 같은 길이·폭·부채꼴 각도로 위험 표시와 피해 범위를 계산하고, 월드의 `ground_at`으로 능선·교량에 표시와 발사체를 맞춘다.

2026-11-18 Godot 4.7.2에서 `godot --headless --path game --script res://tests/enemy_test.gd`를 검증했다. 전체 45종·불지옥 공격 행동 61개, 숲 7종의 클립 49개, 중복 사망 차단, 안전지대, 방어 방향, 보스의 갈퀴 저항, 분열, 바퀴 예고와 뿌리 고리의 안전 틈을 확인했다. 숲 능선의 0.674m 상승 구간에서 표시 정점과 목표 높이의 최대 차이는 0.004m였고, 다리 양쪽 진입로와 상판을 지나는 별도 직선도 통과했다. 같은 능선에서 사슴의 돌진 차선과 고목왕의 뿌리 고리를 Compatibility 렌더러로 촬영해 메시와 예고의 배치를 함께 확인했다. [숲 보스 예고 검수 화면](art/review/forest_telegraphs.png) 자동 검증의 패턴 수는 도감·판정 단위의 결과이며 실제 플레이의 난이도와 회피 성공률은 별도 플레이 평가 대상이다.
