# 숲 캐릭터 원본

2026-11-18 제작 및 확인. Blender 5.2.1 LTS에서 만든 원본은 이 폴더의 `.blend` 파일, 런타임 모델은 `game/assets/models/`의 같은 이름을 가진 GLB다. 설계 기준은 저장소의 `designs.md` 4절이다. 모델의 지면 원점과 Godot 진행 방향 −Z를 기준으로 모든 본과 효과 위치를 맞췄다.

| 파일 이름 | 실루엣과 조형 | 삼각형 | 내보낸 본 | 클립 |
| --- | --- | ---: | ---: | ---: |
| hero | 고글을 쓴 수리공, 청록 스카프, 짧은 앞치마, 화살표 간판검 | 24,642 | 26 | 11 |
| acorn_mouse | 도토리 모자, 큰 귀, 굽은 꼬리와 앞니 | 16,252 | 11 | 7 |
| pine_wasp | 맥이 있는 네 날개, 겹눈, 솔잎과 침 | 7,988 | 9 | 7 |
| moss_boar | 양쪽 엄니, 이끼 갈기와 버섯 무리 | 13,600 | 8 | 7 |
| husk_shield | 여섯 다리, 분할된 등딱지, 앞쪽의 녹색 방패 | 9,908 | 11 | 7 |
| drum_shroom | 점박이 갓, 조임끈 달린 북과 양손 북채 | 12,736 | 8 | 7 |
| trap_antler | 덫니가 돋은 넓은 금속 뿔, 탄력 있는 네 다리 | 15,676 | 17 | 7 |
| wheelback | 어깨에 걸린 두 수레바퀴, 나이테 왕관, 호박빛 심재 | 17,988 | 14 | 7 |

## 편집 및 재생성

작업한 원본은 Blender에서 직접 열 수 있다. 생성 스크립트를 다시 실행하면 해당 원본과 GLB를 재생성하므로 수작업 변경을 먼저 보존한다. 프로젝트 루트에서 다음 PowerShell 명령으로 재현한다.

```powershell
$blenderExe = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blenderExe -b --factory-startup --python-exit-code 1 --python art/blender/hero.py
& $blenderExe -b --factory-startup --python-exit-code 1 --python art/blender/forest_scouts.py
& $blenderExe -b --factory-startup --python-exit-code 1 --python art/blender/forest_band.py
& $blenderExe -b --factory-startup --python-exit-code 1 --python art/blender/forest_bosses.py
python art/blender/verify_glb.py
& $blenderExe -b art/blender/hero.blend --python-exit-code 1 --python art/blender/verify_hero_pose.py
```

`model_tools.py`는 메시, 정점 칠, 그레인 텍스처, 스킨과 액션을 만든다. Blender 원본과 GLB 모두 텍스처를 포함한다. 주인공·사슴·고목왕은 2048², 숲 일반 몬스터는 1024²다. 비단·가죽 등 물체의 바탕색은 메시의 `COLOR_0`에 들어 있다.

주인공의 오른손 아래 `WeaponGrip`이 검 전체를 변형한다. `SwordBase`와 `SwordTip`은 검 궤적을 샘플하는 본이다. `WeaponBase`는 기본 검, `Grade1`~`Grade6`은 누적 표시하는 별도 메시다. Blender 원본에는 손·발 IK 목표와 팔 비틀림 제약이 있다. 제작 액션은 FK 자세로 저장되고 GLB로 베이크된다. 게임 물리가 전진과 판정을 담당한다.

## 검증 및 적용 범위

여덟 GLB를 Godot 4.7.2의 헤드리스 에디터로 임포트했다. `verify_glb.py`는 GLB의 메시·색상·UV·텍스처·본·가중치·클립과 주인공의 기술 길이를 직접 읽는다. 내보낸 정점당 최대 가중치 개수는 2개다. 반올림 7자리에서 합계 오차는 0이었다.

Blender에서 주인공의 모든 클립을 60Hz로 샘플한 손잡이 이탈은 0.000000m였다. 평지를 초속 5m로 달린다고 가정한 소스 자세에서 신발 앞뒤 기준점이 바닥 2cm 안에 머무는 동안 최대 수평 이동은 2.60cm, 최대 지면 침투는 1.5mm였다. 경사·충돌·가속·블렌딩이 있는 실게임 접지는 별도 검증 대상이다.

각 `*_poses.webp`는 38° 내려다본 여덟 방향과 공격의 준비·예고·판정·회복 모습을 담는다. `review_sheets.py`는 Blender와 Python Pillow로 이를 재생성한다. 예를 들어 `python art/blender/review_sheets.py hero wheelback`을 실행한다. `*_review.png`는 주인공과 두 보스의 근접 렌더다. 게임 화면의 가림 처리와 타격 효과는 Godot 쪽 검증 기록을 참조한다.

주인공과 고목왕 메시의 삼각형 수는 설계 초안의 근접 모델 예산보다 낮다. 세부와 선은 정점 칠·입체 부품으로 표현했다. 본 수와 스킨 가중치의 검증만으로 최종 외형이나 실기 성능을 판정할 수 없다.
