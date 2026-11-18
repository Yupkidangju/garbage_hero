# 숲 전투 동작 검수

2026-11-18 · [고목왕 전투 영상](forest_combat.mp4) · [촬영 피처](record_forest_combat.gd)

Godot 4.7.2의 실제 메인 씬에서 쉬움 솔방울 숲과 수레등 고목왕을 불러왔다. 첫 합성과 숲 클리어 상태를 임시 슬롯에 주고 일반 몬스터 소환을 쉬게 한 뒤, 주인공을 보스 옆에서 시작시켰다. 촬영 피처가 정해진 시점에 공격·기술 입력을 보낸다. 보스의 예고와 공격, 피해, 충돌, 애니메이션, 음향, HUD는 게임 코드를 사용했다.

| 영상 시점 | 확인한 동작 |
| --- | --- |
| 0.15–1.35초 | Q 갈퀴가 보스에게 닿고 주황색 직선이 바퀴 경로를 예고한다. 주인공이 회피하고 구르는 바퀴 끝에서 피해를 받는다. |
| 1.55–2.75초 | 기본 3타의 궤적과 체력 감소가 이어진다. 보스는 바퀴 공격을 회복한 뒤 뿌리 고리의 빈 구간을 표시한다. |
| 3.15–4.05초 | E 고철 회오리가 두 번 적중하는 동안 바닥에 뿌리가 솟는다. |
| 4.28–4.67초 | R 압착 강타가 예고 후 내려와 보스 체력이 277에서 253으로 줄어든다. |
| 5.55–8.73초 | 기본 3타·두 번째 바퀴와 갈퀴를 거쳐 다음 뿌리 예고로 이어진다. |

카메라는 게임 기본값인 사선 38°와 정투영 세로 15m를 사용했다. Forward+로 고정 프레임 영상을 출력하고 FFmpeg로 1280×720, 초당 30프레임, 262프레임의 H.264 영상과 스테레오 AAC를 인코딩했다. 게임의 60Hz 동작 시간은 그대로 재생된다. 이 영상에서 프레임 처리 성능이나 일반 입력으로 보스를 만날 때까지의 소요 시간을 측정할 수는 없다. [Godot의 영상 기록 방식](https://docs.godotengine.org/en/4.7/tutorials/animation/creating_movies.html)

## 섬광 약화 비교

기본 설정과 섬광 약화를 각각 임시 설정 파일에서 불러왔다. 첫 공격 전에 활성 플레이어가 해당 값을 받았는지 확인했다. 두 실행 모두 흔들림을 켜고 같은 입력과 치명타 시드를 사용했다. 292번째 물리 틱에서 주인공 체력은 86, 보스 체력은 253으로 같았다.

갈퀴의 진행 화살표, 회오리의 청록색 궤적, 강타의 금색 링을 같은 게임 틱에서 비교했다. 세 효과 모두 약화 설정에서 가늘고 옅게 읽힌다. 회오리가 겹치는 동안 주황색 뿌리 예고의 테두리와 방향 삼각형을 두 화면 모두에서 확인했다. 세 프레임의 픽셀 차이는 주인공 효과 주변에만 나타났다. 시각 피로도나 광과민성에 대한 사용자 평가는 진행하지 않았다. [동일 시점 좌우 비교](forest_flash_comparison.webp)

## 재현

프로젝트 루트에서 `$godotExe`를 Godot 4.7.2 실행 파일로, `$captureDir`을 임시 출력 디렉터리의 절대 경로로 지정한다.

```powershell
$fixture = (Resolve-Path 'art/review/record_forest_combat.gd').Path
& $godotExe --path game --resolution 1280x720 --fixed-fps 30 --write-movie "$captureDir/normal.avi" --script $fixture
ffmpeg -i "$captureDir/normal.avi" -t 8.733333 -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "$captureDir/forest_combat.mp4"
& $godotExe --path game --resolution 1280x720 --fixed-fps 30 --script $fixture -- "--samples=$captureDir"
& $godotExe --path game --resolution 1280x720 --fixed-fps 30 --script $fixture -- "--samples=$captureDir" --reduced
python art/review/compare_forest_fx.py $captureDir
```
