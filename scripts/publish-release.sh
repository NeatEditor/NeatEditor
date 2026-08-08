#!/usr/bin/env bash
# NeatEditor 的 macOS 直分发发布器。
#
# 默认行为：可靠地脱离当前终端后台执行完整发布，日志写入 build/release-logs/。
# 完整链路：归档 → Developer ID 导出 → 签名校验 → 公证并装订 App
# → 制作 dmg → 公证并装订 dmg → Gatekeeper 校验 → GitHub Release。
#
# 用法：
#   scripts/publish-release.sh                 # 后台完整发布
#   scripts/publish-release.sh --local-only    # 后台完成本地产物，不推送
#   scripts/publish-release.sh --foreground    # 在当前终端运行（仅排障）
#   scripts/publish-release.sh --dry-run       # 只检查前置条件和发布配置

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly APP_NAME="NeatEditor"
readonly REPOSITORY="NeatEditor/NeatEditor"
readonly DEFAULT_BRANCH="main"
readonly UPDATE_FEED_URL="https://raw.githubusercontent.com/${REPOSITORY}/main/appcast.xml"
readonly UPDATE_DOWNLOAD_PREFIX="https://github.com/${REPOSITORY}/releases/download"
readonly SPARKLE_ACCOUNT="caozc.top"
readonly TEAM_ID="SHZQ3MWP3B"
readonly SIGN_IDENTITY="Developer ID Application"
readonly NOTARY_KEY="${NOTARY_KEY:-${HOME}/Documents/P8 密钥/发布公证密钥/AuthKey_D7YQ9HD7D6_Notarize.p8}"
readonly NOTARY_KEY_ID="${NOTARY_KEY_ID:-D7YQ9HD7D6}"
readonly NOTARY_ISSUER="${NOTARY_ISSUER:-c98fe4b8-d1bf-4b4a-b998-9eb8f3be9fe4}"
readonly BUILD_DIR="${ROOT_DIR}/build/release"
readonly DERIVED_DATA="${BUILD_DIR}/DerivedData.noindex"
readonly ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
readonly EXPORT_DIR="${BUILD_DIR}/export"
readonly APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
readonly APPCAST_PATH="${ROOT_DIR}/appcast.xml"
readonly NOTARY_TIMEOUT=3600
readonly NOTARY_POLL_INTERVAL=30

local_only=false
foreground=false
dry_run=false
for argument in "$@"; do
  case "${argument}" in
    --local-only) local_only=true ;;
    --foreground) foreground=true ;;
    --dry-run) dry_run=true ;;
    *) printf '未知参数：%s\n' "${argument}" >&2; exit 2 ;;
  esac
done

log_step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# 公证可能需要数十分钟；默认先脱离当前会话再执行。子进程会完整串行后续步骤，
# 不依赖 Agent 或终端保持在线。
if [[ "${foreground}" == false && "${dry_run}" == false && "${NEATEDITOR_RELEASE_CHILD:-}" != "1" ]]; then
  log_dir="${ROOT_DIR}/build/release-logs"
  mkdir -p "${log_dir}"
  log_file="${log_dir}/publish-$(date +%Y%m%d-%H%M%S).log"
  child_args=(--foreground)
  [[ "${local_only}" == true ]] && child_args+=(--local-only)
  NEATEDITOR_RELEASE_CHILD=1 nohup "${BASH_SOURCE[0]}" "${child_args[@]}" \
    >"${log_file}" 2>&1 < /dev/null &
  printf '发布已在后台启动（进程 %s）。日志：%s\n' "$!" "${log_file}"
  exit 0
fi

assert_signed_for_distribution() {
  local target="$1" label="$2" sign_info entitlements
  sign_info="$(codesign -dv --verbose=2 "${target}" 2>&1)"
  entitlements="$(codesign -d --entitlements - "${target}" 2>/dev/null || true)"
  grep -q "Authority=${SIGN_IDENTITY}" <<<"${sign_info}" \
    || die "${label}不是 Developer ID 签名"
  grep -q 'flags=.*runtime' <<<"${sign_info}" \
    || die "${label}未启用加固运行时"
  grep -q '^Timestamp=' <<<"${sign_info}" \
    || die "${label}签名缺少可信时间戳"
  if grep -q 'get-task-allow' <<<"${entitlements}"; then
    die "${label}包含调试权限，不能提交苹果公证"
  fi
  codesign --verify --deep --strict --verbose=2 "${target}" >/dev/null \
    || die "${label}签名结构校验失败"
}

resign_sparkle_framework() {
  local sparkle_framework sparkle_version_dir sparkle_checkout
  sparkle_framework="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
  sparkle_version_dir="${sparkle_framework}/Versions/B"
  sparkle_checkout="${DERIVED_DATA}/SourcePackages/checkouts/Sparkle"

  [[ -d "${sparkle_version_dir}" ]] || die "导出产物未包含 Sparkle.framework"
  [[ -f "${sparkle_checkout}/Downloader/Downloader.entitlements" ]] \
    || die "找不到 Sparkle Downloader 权限清单"

  log_step "重签 Sparkle 内嵌更新组件"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    --entitlements "${sparkle_checkout}/Downloader/Downloader.entitlements" \
    "${sparkle_version_dir}/XPCServices/Downloader.xpc"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${sparkle_version_dir}/XPCServices/Installer.xpc"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${sparkle_version_dir}/Updater.app"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${sparkle_version_dir}/Autoupdate"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${sparkle_framework}"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_PATH}"
}

claim_submission_id() {
  local file_name="$1" started_at="$2" history_json submission_id
  for _ in 1 2 3 4 5; do
    sleep 10
    history_json="$(xcrun notarytool history --key "${NOTARY_KEY}" --key-id "${NOTARY_KEY_ID}" \
      --issuer "${NOTARY_ISSUER}" --output-format json 2>/dev/null)" || continue
    submission_id="$(jq -r --arg name "${file_name}" --arg since "${started_at}" \
      '[.history[]? | select(.name == $name and .createdDate >= $since)] | sort_by(.createdDate) | last | .id // empty' \
      <<<"${history_json}" 2>/dev/null || true)"
    [[ -n "${submission_id}" ]] && { printf '%s\n' "${submission_id}"; return 0; }
  done
  return 1
}

notarize_and_wait() {
  local file="$1" file_name started_at submit_json submission_id status waited=0 info_out failures=0
  file_name="$(basename "${file}")"
  started_at="$(date -u -v-60S +%Y-%m-%dT%H:%M:%SZ)"
  submit_json="$(xcrun notarytool submit "${file}" --key "${NOTARY_KEY}" --key-id "${NOTARY_KEY_ID}" \
    --issuer "${NOTARY_ISSUER}" --output-format json 2>/dev/null)" || submit_json=""
  submission_id="$(jq -r '.id // empty' <<<"${submit_json:-{}}" 2>/dev/null || true)"
  [[ -n "${submission_id}" ]] || submission_id="$(claim_submission_id "${file_name}" "${started_at}")" \
    || die "公证提交未获回执，且无法在苹果侧认领：${file_name}"
  printf '苹果公证提交编号：%s\n' "${submission_id}"

  while (( waited < NOTARY_TIMEOUT )); do
    sleep "${NOTARY_POLL_INTERVAL}"
    waited=$((waited + NOTARY_POLL_INTERVAL))
    info_out="$(xcrun notarytool info "${submission_id}" --key "${NOTARY_KEY}" --key-id "${NOTARY_KEY_ID}" \
      --issuer "${NOTARY_ISSUER}" --output-format json 2>&1)" || true
    status="$(jq -r '.status // empty' <<<"${info_out}" 2>/dev/null || true)"
    if [[ -z "${status}" ]]; then
      failures=$((failures + 1))
      (( failures < 5 )) || die "连续 5 次无法查询公证状态：$(head -1 <<<"${info_out}")"
      continue
    fi
    failures=0
    [[ "${status}" == "In Progress" ]] && continue
    if [[ "${status}" == "Accepted" ]]; then
      printf '苹果公证通过。\n'
      return 0
    fi
    xcrun notarytool log "${submission_id}" --key "${NOTARY_KEY}" --key-id "${NOTARY_KEY_ID}" \
      --issuer "${NOTARY_ISSUER}" 2>/dev/null | head -40 || true
    die "苹果公证被拒：${status}"
  done
  die "公证等待超过 $((NOTARY_TIMEOUT / 60)) 分钟；提交编号为 ${submission_id}"
}

create_dmg() {
  local stage_dir="$1" volume_name="$2" output="$3" macos_major
  macos_major="$(sw_vers -productVersion | cut -d. -f1)"
  rm -f "${output}"
  if (( macos_major >= 26 )); then
    diskutil image create from "${stage_dir}" "${output}" --format UDZO --volumeName "${volume_name}" >/dev/null
  else
    hdiutil create -volname "${volume_name}" -srcfolder "${stage_dir}" -ov -format UDZO "${output}" >/dev/null
  fi
}

cd "${ROOT_DIR}"
log_step "检查发布前置条件"
identities="$(security find-identity -v -p codesigning)"
grep -q "${SIGN_IDENTITY}" <<<"${identities}" || die "钥匙串中没有 Developer ID Application 证书"
[[ -f "${NOTARY_KEY}" ]] || die "找不到苹果公证密钥"
notary_check="$(xcrun notarytool history --key "${NOTARY_KEY}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER}" 2>&1)" \
  || die "苹果公证凭据不可用：$(head -1 <<<"${notary_check}")"
[[ -f project.yml ]] || die "未找到项目配置"
version="$(sed -n 's/^ *MARKETING_VERSION: //p' project.yml | tr -d ' ')"
build_number="$(sed -n 's/^ *CURRENT_PROJECT_VERSION: //p' project.yml | tr -d ' ')"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "展示版本必须是 SemVer"
[[ "${build_number}" =~ ^[1-9][0-9]*$ ]] || die "内部构建号必须是正整数"
readonly version build_number
readonly dmg_path="${BUILD_DIR}/${APP_NAME}-${version}.dmg"

if [[ "${local_only}" == false && "${dry_run}" == false ]]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "完整发布必须在 Git 仓库中运行"
  gh repo view "${REPOSITORY}" --json isPrivate,defaultBranchRef --jq '.isPrivate == false and .defaultBranchRef.name == "main"' \
    | grep -q true || die "GitHub 公开仓或默认分支不符合发布基线"
fi

if [[ "${dry_run}" == true ]]; then
  printf '发布配置检查通过：v%s（内部构建号 %s）。\n' "${version}" "${build_number}"
  exit 0
fi

log_step "生成工程并归档 Developer ID 版本"
xcodegen generate >/dev/null
rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIR}"
xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "${DERIVED_DATA}" -archivePath "${ARCHIVE_PATH}" archive >/dev/null

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
export_options="${work_dir}/ExportOptions.plist"
cat > "${export_options}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
  <key>destination</key><string>export</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "${ARCHIVE_PATH}" -exportOptionsPlist "${export_options}" \
  -exportPath "${EXPORT_DIR}" >/dev/null
[[ -d "${APP_PATH}" ]] || die "Developer ID 导出产物不存在"
readonly sparkle_bin_dir="${DERIVED_DATA}/SourcePackages/artifacts/sparkle/Sparkle/bin"
[[ -x "${sparkle_bin_dir}/generate_appcast" ]] || die "找不到 Sparkle 的 generate_appcast 工具"
resign_sparkle_framework

sparkle_public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true)"
[[ -n "${sparkle_public_key}" ]] || die "应用缺少 Sparkle 更新公钥"
[[ "$("${sparkle_bin_dir}/generate_keys" --account "${SPARKLE_ACCOUNT}" -p 2>/dev/null)" == "${sparkle_public_key}" ]] \
  || die "钥匙串中的 Sparkle 更新签名密钥缺失或与应用公钥不匹配"

log_step "校验签名与加固运行时"
assert_signed_for_distribution "${APP_PATH}" "NeatEditor"

log_step "提交应用本体公证并装订票据"
notary_zip="${BUILD_DIR}/${APP_NAME}-${version}-notarize.zip"
rm -f "${notary_zip}"
ditto -c -k --keepParent "${APP_PATH}" "${notary_zip}"
notarize_and_wait "${notary_zip}"
xcrun stapler staple "${APP_PATH}" >/dev/null

log_step "生成 Sparkle 签名更新包与更新清单"
update_zip_path="${BUILD_DIR}/${APP_NAME}-${version}.zip"
appcast_dir="${work_dir}/appcast"
release_notes_file="${appcast_dir}/${APP_NAME}-${version}.md"
mkdir -p "${appcast_dir}"
rm -f "${update_zip_path}"
ditto -c -k --keepParent "${APP_PATH}" "${update_zip_path}"
ditto "${update_zip_path}" "${appcast_dir}/$(basename "${update_zip_path}")"
cat > "${release_notes_file}" <<EOF
# NeatEditor ${version}

- 更新包经过 Sparkle EdDSA 签名、Developer ID 签名与苹果公证。
EOF
[[ -f "${APPCAST_PATH}" ]] && ditto "${APPCAST_PATH}" "${appcast_dir}/appcast.xml"
"${sparkle_bin_dir}/generate_appcast" \
  --account "${SPARKLE_ACCOUNT}" \
  --download-url-prefix "${UPDATE_DOWNLOAD_PREFIX}/v${version}/" \
  --embed-release-notes \
  --link "https://github.com/${REPOSITORY}" \
  --versions "${build_number}" \
  --maximum-versions 10 \
  -o "${appcast_dir}/appcast.xml" \
  "${appcast_dir}" >/dev/null || die "生成 Sparkle 更新清单失败"
xmllint --noout "${appcast_dir}/appcast.xml" || die "Sparkle 更新清单不是合法 XML"
grep -q 'sparkle:edSignature=' "${appcast_dir}/appcast.xml" \
  || die "Sparkle 更新清单缺少 EdDSA 签名"

log_step "制作 dmg 并公证"
stage_dir="${work_dir}/dmg"
mkdir -p "${stage_dir}"
ditto "${APP_PATH}" "${stage_dir}/${APP_NAME}.app"
ln -s /Applications "${stage_dir}/Applications"
create_dmg "${stage_dir}" "${APP_NAME} ${version}" "${dmg_path}" || die "dmg 制作失败"
notarize_and_wait "${dmg_path}"
xcrun stapler staple "${dmg_path}" >/dev/null

log_step "验证陌生用户安装链路"
gatekeeper_result="$(spctl -a -vvv -t exec "${APP_PATH}" 2>&1 || true)"
grep -q accepted <<<"${gatekeeper_result}" || die "Gatekeeper 校验未通过：$(head -3 <<<"${gatekeeper_result}")"
xcrun stapler validate "${dmg_path}" >/dev/null || die "dmg 票据校验失败"
shasum -a 256 "${dmg_path}" > "${dmg_path}.sha256"

if [[ "${local_only}" == true ]]; then
  printf '本地发布产物已验证：%s（更新包：%s）\n' "${dmg_path}" "${update_zip_path}"
  exit 0
fi

log_step "提交、打标签并发布 GitHub Release"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 发布 v${version}"
fi
if ! git rev-parse "v${version}" >/dev/null 2>&1; then
  git tag -a "v${version}" -m "v${version}"
fi
git push origin "${DEFAULT_BRANCH}"
git push origin "v${version}"
notes="NeatEditor ${version}\n\n- 此安装包已通过 Developer ID 签名、苹果公证和票据装订。\n- 下载 dmg 后拖入 Applications 即可安装。\n- 已支持应用内自动检查、下载和安装更新。"
gh release create "v${version}" --repo "${REPOSITORY}" --title "v${version}" --notes "${notes}" 2>/dev/null || true
gh release upload "v${version}" "${dmg_path}" "${dmg_path}.sha256" "${update_zip_path}" --repo "${REPOSITORY}" --clobber
ditto "${appcast_dir}/appcast.xml" "${APPCAST_PATH}"
git add "${APPCAST_PATH}"
if ! git diff --cached --quiet; then
  git commit -m "chore: 发布 v${version} 更新清单"
  git push origin "${DEFAULT_BRANCH}"
fi
asset_url="https://github.com/${REPOSITORY}/releases/download/v${version}/$(basename "${dmg_path}")"
update_url="${UPDATE_DOWNLOAD_PREFIX}/v${version}/$(basename "${update_zip_path}")"
curl -fsSL --range 0-0 "${asset_url}" -o /dev/null || die "公开安装包无法匿名下载"
curl -fsSL "${UPDATE_FEED_URL}" -o "${work_dir}/published-appcast.xml" \
  || die "公开更新清单无法匿名下载"
xmllint --noout "${work_dir}/published-appcast.xml" || die "公开更新清单不是合法 XML"
grep -q "<sparkle:version>${build_number}</sparkle:version>" "${work_dir}/published-appcast.xml" \
  || die "公开更新清单没有当前内部构建号 ${build_number}"
curl -fsSL --range 0-0 "${update_url}" -o /dev/null || die "Sparkle 更新包无法匿名下载"
printf '发布完成：%s（自动更新：%s）\n' "${asset_url}" "${UPDATE_FEED_URL}"
