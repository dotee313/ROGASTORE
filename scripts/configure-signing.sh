#!/usr/bin/env bash
# يضبط توقيع إصدار APK بمفتاح ثابت مخزّن في GitHub Secrets.
# يُستدعى بعد `flutter create` وقبل `flutter build apk --release`.
set -euo pipefail

: "${ANDROID_KEYSTORE_BASE64:?ANDROID_KEYSTORE_BASE64 is missing}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is missing}"
: "${ANDROID_KEY_ALIAS:?ANDROID_KEY_ALIAS is missing}"
: "${ANDROID_KEY_PASSWORD:?ANDROID_KEY_PASSWORD is missing}"

mkdir -p android/app
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/roga-release.jks

python3 - <<'PY'
import os
import re
from pathlib import Path

alias = os.environ['ANDROID_KEY_ALIAS']
store_pass = os.environ['ANDROID_KEYSTORE_PASSWORD']
key_pass = os.environ['ANDROID_KEY_PASSWORD']

kts = Path('android/app/build.gradle.kts')
groovy = Path('android/app/build.gradle')

if kts.exists():
    p = kts
    text = p.read_text()
    if not re.search(r'signingConfigs\s*\{', text):
        block = (
            '    signingConfigs {\n'
            f'        create("{alias}") {{\n'
            '            storeFile = file("../roga-release.jks")\n'
            f'            storePassword = "{store_pass}"\n'
            f'            keyAlias = "{alias}"\n'
            f'            keyPassword = "{key_pass}"\n'
            '            isV1SigningEnabled = true\n'
            '        }\n'
            '    }\n'
        )
        text = text.replace('    buildTypes {', block + '\n    buildTypes {', 1)
    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        f'signingConfig = signingConfigs.getByName("{alias}")',
    )
    if not re.search(r'create\("' + re.escape(alias) + r'"\)', text):
        raise SystemExit('Kotlin DSL signing config was not applied')
    p.write_text(text)
elif groovy.exists():
    p = groovy
    text = p.read_text()
    if not re.search(r'signingConfigs\s*\{', text):
        block = (
            '    signingConfigs {\n'
            '        release {\n'
            '            storeFile file("../roga-release.jks")\n'
            f"            storePassword '{store_pass}'\n"
            f"            keyAlias '{alias}'\n"
            f"            keyPassword '{key_pass}'\n"
            '            v1SigningEnabled true\n'
            '        }\n'
            '    }\n'
        )
        text = text.replace('    buildTypes {', block + '\n    buildTypes {', 1)
    text = text.replace(
        'signingConfig signingConfigs.debug',
        'signingConfig signingConfigs.release',
    )
    if 'signingConfig signingConfigs.release' not in text:
        raise SystemExit('Groovy signing config was not applied')
    p.write_text(text)
else:
    raise SystemExit('No android/app/build.gradle(.kts) found')

print('Release signing configured:', p)
PY
