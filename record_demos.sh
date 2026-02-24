#!/bin/zsh
#
#  record_demos.sh
#  FLO - Finance Ledger Optimizer
#
#  Version 2.1 - Fixed scene list to match FLODemoTests.swift v2.0
#  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
#
#  PURPOSE: Runs FLODemoTests one scene at a time while capturing
#  simulator video via `xcrun simctl io recordVideo`. Each test
#  produces a standalone .mp4 in ~/FLO_Demo_Videos/.
#
#  USAGE:
#    chmod +x record_demos.sh
#    ./record_demos.sh                  # Record ALL scenes
#    ./record_demos.sh 01               # Record scene 01 only
#    ./record_demos.sh 01 03 07         # Record scenes 01, 03, 07
#    ./record_demos.sh --list           # List available scenes
#    ./record_demos.sh --clean          # Delete all recorded videos
#
#  REQUIREMENTS:
#    - Xcode 15+ installed
#    - Simulator runtime (iOS 17+ recommended)
#    - FLO project builds successfully
#
#  OUTPUT:
#    ~/FLO_Demo_Videos/
#    ├── 01_OnboardingFlow.mp4
#    ├── 02_DashboardTour.mp4
#    ├── 03_AddTransaction.mp4
#    └── ... (one .mp4 per scene)
#
#  CHANGES v2.1:
#  ✅ Fixed scene 22-36 method names to match FLODemoTests.swift v2.0
#  ✅ Added scenes 37-38 (SplitReceipt, QuickActions)
#  ✅ Total: 38 scenes
#
#  CHANGES v2.0:
#  ✅ Added scenes 21-36 covering remaining FLO capabilities
#  ✅ Added -parallel-testing-enabled NO to prevent clone simulator issues
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

PROJECT_NAME="FLO"
SCHEME_NAME="FLO"
TEST_TARGET="FLOUITests"
TEST_CLASS="FLODemoTests"
OUTPUT_DIR="$HOME/FLO_Demo_Videos"
SIMULATOR_NAME="iPhone 16 Pro"  # Change to match your preferred device
CODEC="h264"                     # h264 for compatibility, hevc for smaller files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$OUTPUT_DIR/recording_log_${TIMESTAMP}.txt"

# ═══════════════════════════════════════════════════════════════
# Scene Definitions — must match FLODemoTests.swift v2.0 exactly
# Format: "scene_number|test_method|output_filename"
# ═══════════════════════════════════════════════════════════════

SCENE_LIST=(
    # ─── CORE FEATURES (01-20) ───
    "01|testDemo_01_OnboardingFlow|01_OnboardingFlow"
    "02|testDemo_02_DashboardTour|02_DashboardTour"
    "03|testDemo_03_AddTransaction|03_AddTransaction"
    "04|testDemo_04_TransactionList|04_TransactionList"
    "05|testDemo_05_CreateBudget|05_CreateBudget"
    "06|testDemo_06_BudgetOverview|06_BudgetOverview"
    "07|testDemo_07_CreateInvoice|07_CreateInvoice"
    "08|testDemo_08_InvoiceTracking|08_InvoiceTracking"
    "09|testDemo_09_AccountsOverview|09_AccountsOverview"
    "10|testDemo_10_MileageTracking|10_MileageTracking"
    "11|testDemo_11_ManualTripEntry|11_ManualTripEntry"
    "12|testDemo_12_RecurringTransactions|12_RecurringTransactions"
    "13|testDemo_13_TaxDeductions|13_TaxDeductions"
    "14|testDemo_14_ReportsAnalytics|14_ReportsAnalytics"
    "15|testDemo_15_ClientManagement|15_ClientManagement"
    "16|testDemo_16_CategoryManagement|16_CategoryManagement"
    "17|testDemo_17_ColorThemes|17_ColorThemes"
    "18|testDemo_18_SettingsMenu|18_SettingsMenu"
    "19|testDemo_19_QuickTabTour|19_QuickTabTour"
    "20|testDemo_20_SubscriptionTiers|20_SubscriptionTiers"
    # ─── EXTENDED FEATURES (21-38) ───
    "21|testDemo_21_ReceiptScanning|21_ReceiptScanning"
    "22|testDemo_22_CreditCardManagement|22_CreditCardManagement"
    "23|testDemo_23_DebtPayoffCalculator|23_DebtPayoffCalculator"
    "24|testDemo_24_ExportOptions|24_ExportOptions"
    "25|testDemo_25_ProfitLossReport|25_ProfitLossReport"
    "26|testDemo_26_YearEndTaxChecklist|26_YearEndTaxChecklist"
    "27|testDemo_27_MoveMoneyTransfers|27_MoveMoneyTransfers"
    "28|testDemo_28_BusinessProfileSetup|28_BusinessProfileSetup"
    "29|testDemo_29_TaxSettings|29_TaxSettings"
    "30|testDemo_30_MoneyMovesInsights|30_MoneyMovesInsights"
    "31|testDemo_31_SecurityPasscode|31_SecurityPasscode"
    "32|testDemo_32_ComprehensiveReport|32_ComprehensiveReport"
    "33|testDemo_33_EditTransactionDetail|33_EditTransactionDetail"
    "34|testDemo_34_InvoiceDetailView|34_InvoiceDetailView"
    "35|testDemo_35_BudgetHistory|35_BudgetHistory"
    "36|testDemo_36_ReceiptMatchingQueue|36_ReceiptMatchingQueue"
    "37|testDemo_37_SplitReceipt|37_SplitReceipt"
    "38|testDemo_38_QuickActions|38_QuickActions"
)

# Lookup scene data by number. Returns "method|filename" or empty string.
get_scene() {
    local num="$1"
    for entry in "${SCENE_LIST[@]}"; do
        local scene_num="${entry%%|*}"
        if [[ "$scene_num" == "$num" ]]; then
            echo "${entry#*|}"
            return 0
        fi
    done
    echo ""
    return 1
}

# Get all scene numbers in order
all_scene_numbers() {
    for entry in "${SCENE_LIST[@]}"; do
        echo "${entry%%|*}"
    done
}

# ═══════════════════════════════════════════════════════════════
# Color Output
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { print "${CYAN}[FLO Demo]${NC} $1"; }
success() { print "${GREEN}[FLO Demo] OK${NC} $1"; }
warn()    { print "${YELLOW}[FLO Demo] WARNING${NC} $1"; }
error()   { print "${RED}[FLO Demo] ERROR${NC} $1"; }
header()  { print "\n${BLUE}=======================================${NC}\n${BLUE}  $1${NC}\n${BLUE}=======================================${NC}"; }

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

list_scenes() {
    header "Available Demo Scenes (38 Total)"
    print ""
    print "  ${BLUE}── Core Features ──${NC}"
    for entry in "${SCENE_LIST[@]}"; do
        local num="${entry%%|*}"
        local rest="${entry#*|}"
        local filename="${rest#*|}"
        if [[ "$num" == "21" ]]; then
            print ""
            print "  ${BLUE}── Extended Features ──${NC}"
        fi
        print "  Scene $num: $filename"
    done
    print ""
    print "Usage: ./record_demos.sh [scene_numbers...]"
    print "  ./record_demos.sh           # Record all 38"
    print "  ./record_demos.sh 01 03 07  # Record specific scenes"
    print "  ./record_demos.sh 21 38     # Record extended scenes"
}

clean_videos() {
    header "Cleaning Video Output"
    if [[ -d "$OUTPUT_DIR" ]]; then
        rm -rf "$OUTPUT_DIR"
        success "Deleted $OUTPUT_DIR"
    else
        warn "No videos found to clean"
    fi
}

get_booted_simulator_udid() {
    xcrun simctl list devices booted -j 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for device in devices:
        if device.get('state') == 'Booted':
            print(device['udid'])
            sys.exit(0)
" 2>/dev/null || echo ""
}

boot_simulator() {
    local udid
    udid=$(get_booted_simulator_udid)
    
    if [[ -n "$udid" ]]; then
        log "Simulator already booted: $udid"
        return 0
    fi
    
    log "Booting simulator: $SIMULATOR_NAME"
    
    udid=$(xcrun simctl list devices available -j 2>/dev/null | \
        python3 -c "
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' in runtime:
        for device in devices:
            if device.get('name') == name and device.get('isAvailable', False):
                print(device['udid'])
                sys.exit(0)
print('')
" "$SIMULATOR_NAME" 2>/dev/null)
    
    if [[ -z "$udid" ]]; then
        error "Could not find simulator: $SIMULATOR_NAME"
        error "Available simulators:"
        xcrun simctl list devices available | grep -i iphone | head -10
        exit 1
    fi
    
    xcrun simctl boot "$udid" 2>/dev/null || true
    sleep 3
    open -a Simulator
    sleep 2
    
    success "Simulator booted: $SIMULATOR_NAME ($udid)"
}

get_simulator_udid() {
    get_booted_simulator_udid
}

# ═══════════════════════════════════════════════════════════════
# Recording Functions
# ═══════════════════════════════════════════════════════════════

record_scene() {
    local scene_num="$1"
    local scene_data
    scene_data=$(get_scene "$scene_num") || true
    
    if [[ -z "$scene_data" ]]; then
        error "Unknown scene: $scene_num"
        return 1
    fi
    
    local test_method="${scene_data%%|*}"
    local filename="${scene_data#*|}"
    
    local output_file="$OUTPUT_DIR/${filename}.mp4"
    local full_test_name="${TEST_TARGET}/${TEST_CLASS}/${test_method}"
    local sim_udid
    sim_udid=$(get_simulator_udid)
    
    if [[ -z "$sim_udid" ]]; then
        error "No booted simulator found"
        return 1
    fi
    
    header "Recording Scene $scene_num: $filename"
    log "Test: $full_test_name"
    log "Output: $output_file"
    log "Simulator: $sim_udid"
    
    # Start recording in background
    log "Starting video recording..."
    xcrun simctl io "$sim_udid" recordVideo \
        --codec="$CODEC" \
        --force \
        "$output_file" &
    local record_pid=$!
    
    sleep 1
    
    # Run the specific UI test
    log "Running test: $test_method..."
    local test_start
    test_start=$(date +%s)
    
    # Find the project/workspace
    local project_arg=""
    if [[ -f "${PROJECT_NAME}.xcworkspace/contents.xcworkspacedata" ]]; then
        project_arg="-workspace ${PROJECT_NAME}.xcworkspace"
    elif [[ -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]]; then
        project_arg="-project ${PROJECT_NAME}.xcodeproj"
    else
        local found_project
        found_project=$(find . -maxdepth 1 -name "*.xcworkspace" -not -name "*.xcodeproj" | head -1)
        if [[ -n "$found_project" ]]; then
            project_arg="-workspace $found_project"
        else
            found_project=$(find . -maxdepth 1 -name "*.xcodeproj" | head -1)
            if [[ -n "$found_project" ]]; then
                project_arg="-project $found_project"
            fi
        fi
    fi
    
    local test_result=0
    xcodebuild test \
        ${=project_arg} \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,id=$sim_udid" \
        -only-testing:"$full_test_name" \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee -a "$LOG_FILE" | grep -E "(Test Case|passed|failed|error:)" || test_result=$?
    
    local test_end
    test_end=$(date +%s)
    local duration=$((test_end - test_start))
    
    # Stop recording
    log "Stopping video recording..."
    kill -INT "$record_pid" 2>/dev/null || true
    wait "$record_pid" 2>/dev/null || true
    sleep 1
    
    # Check results
    if [[ -f "$output_file" ]]; then
        local file_size
        file_size=$(du -h "$output_file" | cut -f1)
        success "Recorded: $filename.mp4 ($file_size, ${duration}s)"
    else
        error "Recording failed: $filename.mp4"
    fi
    
    if [[ $test_result -ne 0 ]]; then
        warn "Test had issues (exit code: $test_result) — video may still be usable"
    fi
    
    echo "" >> "$LOG_FILE"
    echo "Scene $scene_num: $filename — ${duration}s (exit: $test_result)" >> "$LOG_FILE"
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

generate_summary() {
    header "Recording Summary"
    
    local total=0
    local recorded=0
    
    print ""
    print "Output directory: $OUTPUT_DIR"
    print ""
    
    for entry in "${SCENE_LIST[@]}"; do
        local num="${entry%%|*}"
        local rest="${entry#*|}"
        local filename="${rest#*|}"
        local file="$OUTPUT_DIR/${filename}.mp4"
        total=$((total + 1))
        
        if [[ -f "$file" ]]; then
            local size
            size=$(du -h "$file" | cut -f1)
            success "  $filename.mp4 ($size)"
            recorded=$((recorded + 1))
        else
            warn "  $filename.mp4 (missing)"
        fi
    done
    
    print ""
    log "Recorded: $recorded / $total scenes"
    log "Log file: $LOG_FILE"
    print ""
    
    if [[ $recorded -gt 0 ]]; then
        success "Videos ready in: $OUTPUT_DIR"
        print ""
        print "Next steps:"
        print "  1. Review videos in QuickTime / VLC"
        print "  2. Trim start/end with: ffmpeg -i input.mp4 -ss 1 -t 25 output.mp4"
        print "  3. Add device frame with: ffmpeg -i input.mp4 -vf 'pad=...' framed.mp4"
        print "  4. Convert to GIF: ffmpeg -i input.mp4 -vf 'fps=15,scale=320:-1' output.gif"
    fi
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

main() {
    case "${1:-}" in
        --list|-l)
            list_scenes
            exit 0
            ;;
        --clean|-c)
            clean_videos
            exit 0
            ;;
        --help|-h)
            print "FLO Demo Video Recorder v2.1"
            print ""
            print "Usage: ./record_demos.sh [options] [scene_numbers...]"
            print ""
            print "Options:"
            print "  --list, -l     List all 38 available scenes"
            print "  --clean, -c    Delete all recorded videos"
            print "  --help, -h     Show this help"
            print ""
            print "Examples:"
            print "  ./record_demos.sh               # Record all 38 scenes"
            print "  ./record_demos.sh 01             # Record scene 01 only"
            print "  ./record_demos.sh 01 03 07       # Record specific scenes"
            print "  ./record_demos.sh 21 38          # Record extended scenes"
            exit 0
            ;;
    esac
    
    header "FLO Demo Video Recorder v2.1"
    log "Starting at $(date)"
    log "38 scenes available (FLODemoTests.swift v2.0)"
    
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/results"
    
    echo "FLO Demo Recording — $(date)" > "$LOG_FILE"
    echo "Simulator: $SIMULATOR_NAME" >> "$LOG_FILE"
    echo "Codec: $CODEC" >> "$LOG_FILE"
    echo "Scenes: 38 (FLODemoTests.swift v2.0)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    boot_simulator
    
    local scenes_to_record=()
    
    if [[ $# -eq 0 ]]; then
        while IFS= read -r num; do
            scenes_to_record+=("$num")
        done < <(all_scene_numbers)
        log "Recording ALL ${#scenes_to_record[@]} scenes"
    else
        for scene_num in "$@"; do
            local padded
            padded=$(printf "%02d" "$scene_num" 2>/dev/null || echo "$scene_num")
            
            local check
            check=$(get_scene "$padded") || true
            if [[ -n "$check" ]]; then
                scenes_to_record+=("$padded")
            else
                warn "Unknown scene: $scene_num (skipping)"
            fi
        done
        log "Recording ${#scenes_to_record[@]} scene(s): ${scenes_to_record[*]}"
    fi
    
    local failures=0
    for scene_num in "${scenes_to_record[@]}"; do
        record_scene "$scene_num" || failures=$((failures + 1))
        sleep 2
    done
    
    generate_summary
    
    if [[ $failures -gt 0 ]]; then
        warn "$failures scene(s) had issues — check log: $LOG_FILE"
        exit 1
    fi
    
    success "All recordings complete!"
}

main "$@"
