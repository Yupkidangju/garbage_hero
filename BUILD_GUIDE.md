# Windows·Linux 배포

2026-11-18 KST. 첫 공개 버전은 0.1.0으로 정했다. Godot 4.7.2 공식 표준 에디터와 같은 버전의 x86_64 릴리즈 템플릿을 사용한다. 작업 순서는 프로젝트 버전·공개 라이선스 반영, 두 내보내기 프리셋 작성, 로컬 패키징, GitHub의 각 운영체제에서 테스트, 태그 릴리즈 게시다. 첫 공개의 완료 조건은 두 운영체제에서 압축을 푼 게임이 기동하고, 공개 릴리즈에서 두 패키지와 SHA-256 목록을 내려받아 검증할 수 있는 것이다.

## 로컬 빌드

Python 3.12 이상과 Godot 4.7.2 표준 에디터가 필요하다. Godot의 내보내기 템플릿 관리에서 4.7.2 템플릿을 설치한다. `godot`이 PATH에 있거나 `GODOT_PATH`가 에디터 실행 파일을 가리켜야 한다. 명령은 저장소 루트에서 실행한다. [공식 엔진과 템플릿](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)

```sh
python scripts/build.py --target windows --test --smoke
python scripts/build.py --target linux --test --smoke
```

각 명령의 `--smoke`는 대상 운영체제에서 사용한다. Windows 또는 Linux 한 대에서 두 패키지를 교차 빌드하려면 `python scripts/build.py --target all`을 사용한다. Linux에서 Python 명령이 `python3`인 경우 해당 이름으로 실행한다. `--output`으로 출력 폴더를 선택할 수 있다.

`dist/`에 Windows ZIP과 Linux tar.gz가 생성된다. 각각 실행 파일, 게임 데이터, Apache LICENSE·NOTICE, Godot 및 글꼴의 고지를 포함한다. Linux 파일에는 실행 권한을 기록한다. `--test`는 저장·월드·전투·필드 경로의 회귀 테스트를 실행한다. `--smoke`는 완성된 압축 파일을 임시 폴더에 풀고 실제 바이너리로 메인 씬을 120프레임 실행한다. 별도 슬롯에 생성된 저장의 헤더와 SHA-256까지 확인한다. 그래픽 드라이버와 실제 플레이 성능은 [기존 검증 기록](IMPLEMENTATION_SUMMARY.md)에 있다.

## GitHub Actions와 릴리즈

- `main` 푸시와 PR에서는 Ubuntu와 Windows 러너가 각각 자기 운영체제의 패키지를 테스트하고 Actions 아티팩트를 남긴다. Actions 탭에서 수동 실행도 가능하다.
- CI는 공식 에디터·템플릿 다운로드의 SHA-256을 확인하고 작업 디렉터리의 `.tools/godot/`에 설치한다. 이 디렉터리는 CI 캐시로 재사용한다.
- 릴리즈하려면 `game/project.godot`의 `config/version`과 CHANGELOG의 버전 절을 맞춘 후 해당 커밋에 `vX.Y.Z` 태그를 푸시한다. 태그와 게임 버전이 다르면 빌드가 실패한다.
- 두 플랫폼이 모두 통과하면 게시 작업이 GitHub 초안 릴리즈에 검증된 패키지와 `SHA256SUMS.txt`를 올리고 공개한다. Actions 내 쓰기 권한은 게시 작업에 설정했다. [워크플로](.github/workflows/build-release.yml)

다운로드 폴더에서 Linux는 `sha256sum --check SHA256SUMS.txt`로 두 파일을 확인할 수 있다. Windows는 `Get-FileHash -Algorithm SHA256 .\GarbageHero-v0.1.0-windows-x86_64.zip` 결과를 목록의 같은 파일과 비교한다.
