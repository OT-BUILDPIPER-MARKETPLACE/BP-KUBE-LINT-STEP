#!/bin/bash
# Disable exit-on-error
set -uo pipefail
set +e

if [ "${DEBUG:-false}" = true ]; then
  set -x
fi

# --------------------------------------------------------------
# Load BuildPiper utilities
# --------------------------------------------------------------
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

# --------------------------------------------------------------
# Variables
# --------------------------------------------------------------
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
REPORTS_DIR="${CODEBASE_LOCATION}/reports"
TXT_REPORT="${REPORTS_DIR}/kube-lint-report.txt"
CSV_REPORT="${REPORTS_DIR}/kube-lint-report.csv"

# --------------------------------------------------------------
# Prepare directory
# --------------------------------------------------------------
if [ ! -d "$REPORTS_DIR" ]; then
    logInfoMessage "Directory does not exist. Creating: $REPORTS_DIR"
    mkdir -p "$REPORTS_DIR" || logWarningMessage "Failed to create $REPORTS_DIR"
else
    logInfoMessage "Directory already exists: $REPORTS_DIR"
fi

chmod -R 0777 "${REPORTS_DIR}" 2>/dev/null || logWarningMessage "chmod failed"

# --------------------------------------------------------------
# Validate codebase
# --------------------------------------------------------------
cd "${CODEBASE_LOCATION}" || {
  logErrorMessage "Codebase directory not found: ${CODEBASE_LOCATION}"
}

logInfoMessage "=============================================================="
logInfoMessage " Starting KubeLinter Scan..."
logInfoMessage "=============================================================="
logInfoMessage " Codebase location : ${CODEBASE_LOCATION}"
logInfoMessage " Reports directory  : ${REPORTS_DIR}"
logInfoMessage " Txt report file    : ${TXT_REPORT}"
logInfoMessage " CSV report file    : ${CSV_REPORT}"
logInfoMessage "=============================================================="

if ! command -v kube-linter &>/dev/null; then
  logErrorMessage "KubeLinter is not installed or not found in PATH."
else
  logInfoMessage "Using KubeLinter version:"
  kube-linter version || logWarningMessage "Failed to get kube-linter version"
fi

logInfoMessage "--------------------------------------------------------------"

# --------------------------------------------------------------
# Run kube-linter
# --------------------------------------------------------------
logInfoMessage "Running kube-linter scan..."
kube-linter lint . > "${TXT_REPORT}" 2>&1 || logWarningMessage "kube-linter returned non-zero exit code"

logInfoMessage "TXT report generated: ${TXT_REPORT}"

# --------------------------------------------------------------
# Convert TXT to CSV
# --------------------------------------------------------------
logInfoMessage "Generating CSV report: ${CSV_REPORT}"

echo "file_path,object,message,check,remediation" > "$CSV_REPORT"

grep -v "KubeLinter" "${TXT_REPORT}" | grep ":" | while IFS= read -r line; do

    FILE_PATH=$(echo "$line" | cut -d':' -f1)

    OBJECT=$(echo "$line" | sed -n 's/.*(object: \(.*\)) .*(check:.*/\1/p')
    MESSAGE=$(echo "$line" | sed -n 's/.*) \(.*\) (check:.*/\1/p')
    CHECK=$(echo "$line" | sed -n 's/.*(check: \([^,]*\),.*/\1/p')
    REMEDIATION=$(echo "$line" | sed -n 's/.*remediation: \(.*\)).*/\1/p')

    OBJECT_ESCAPED=$(echo "$OBJECT" | sed 's/,/;/g')
    MESSAGE_ESCAPED=$(echo "$MESSAGE" | sed 's/,/;/g')
    REMEDIATION_ESCAPED=$(echo "$REMEDIATION" | sed 's/,/;/g')

    echo "${FILE_PATH},\"${OBJECT_ESCAPED}\",\"${MESSAGE_ESCAPED}\",${CHECK},\"${REMEDIATION_ESCAPED}\"" >> "$CSV_REPORT"

done || logWarningMessage "CSV generation loop encountered errors"

logInfoMessage "CSV report generated: ${CSV_REPORT}"

# --------------------------------------------------------------
# Copy to BP execution directory
# --------------------------------------------------------------
if [[ -n "${GLOBAL_TASK_ID:-}" ]]; then
  TARGET_DIR="/bp/execution_dir/${GLOBAL_TASK_ID}/"
  logInfoMessage "Copying reports to ${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  cp -rf "${REPORTS_DIR}/." "${TARGET_DIR}" || logWarningMessage "Copy failed"
else
  logWarningMessage "GLOBAL_TASK_ID not set; skipping copy to /bp/execution_dir/"
fi

saveTaskStatus 0 ${ACTIVITY_SUB_TASK_CODE}
