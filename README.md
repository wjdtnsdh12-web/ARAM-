# ARAM AI Analyzer - Android

개인용 Flutter Android 앱이야. Riot ID로 최근 칼바람 경기를 조회하고,
10인 지표와 OpenAI 코칭을 보여줘.

## 보안 구조

- Riot/OpenAI API 키는 소스나 APK에 포함되지 않아.
- 사용자가 앱 설정에서 직접 입력해.
- `flutter_secure_storage`를 통해 Android 암호화 저장소에 보관해.
- 전적 조회는 Riot 공식 API, AI 분석은 OpenAI Responses API에만 요청해.

## APK 자동 생성 - 추천

1. 이 폴더를 GitHub 저장소에 올려.
2. GitHub의 **Actions** 탭을 열어.
3. **Build Android APK**를 선택하고 **Run workflow**를 눌러.
4. 완료된 작업의 `ARAM-AI-Analyzer-APK` 파일을 내려받아.
5. 압축 안의 `ARAM-AI-Analyzer-OpenAI-v0.2.0.apk`를 휴대폰에 설치해.

## PC에서 직접 빌드

Flutter SDK와 Android SDK를 설치한 뒤 프로젝트 폴더에서 실행해.

```powershell
flutter create --platforms=android --org com.soonolab .
flutter pub get
flutter test
flutter build apk --release
```

생성 위치:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## 사용법

1. Riot Developer Portal에서 개발 키를 발급받아.
2. https://platform.openai.com/api-keys 에서 OpenAI API 키를 발급받고
   Platform의 Billing에서 API 결제를 설정해.
3. 앱 설정에서 두 키를 저장해.
4. Riot ID와 태그를 입력하고 검색해.
5. 경기를 선택해 상세 지표와 AI 피드백을 확인해.

Riot 개발 키는 24시간마다 만료되므로 403 오류가 나오면 갱신해야 해.
OpenAI API는 ChatGPT 구독과 별도이며 Platform 사용량에 따라 과금될 수 있어.

## Riot notice

ARAM AI Analyzer isn't endorsed by Riot Games and doesn't reflect the views or
opinions of Riot Games or anyone officially involved in producing or managing
Riot Games properties. Riot Games, and all associated properties are trademarks
or registered trademarks of Riot Games, Inc.
