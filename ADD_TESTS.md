# Adding Test Target to Xcode Project

I've created comprehensive unit tests for the step tracking fixes, but they need to be added to your Xcode project.

## Test Files Created

1. **RouteManagerTests.swift** - Unit tests for RouteManager logic
   - Tests startingSteps recalculation fix
   - Tests daily contribution tracking
   - Tests route switching
   - Tests persistence

2. **StepTrackingTests.swift** - Integration tests for step tracking
   - Tests the exact bug scenario you reported
   - Tests backfill logic
   - Tests same-day reopening
   - Tests day boundary crossing

## Option 1: Add Test Target via Xcode (Recommended)

1. Open `walkanywhere.xcodeproj` in Xcode
2. Select the project in the navigator
3. Click the "+" button at the bottom of the targets list
4. Choose "iOS" → "Unit Testing Bundle"
5. Name it: `walkanywhereTests`
6. Click "Finish"
7. Delete the default test file Xcode creates
8. Add the test files:
   - Right-click on `walkanywhereTests` group
   - "Add Files to walkanywhere..."
   - Navigate to `walkanywhereTests/` folder
   - Select both `.swift` test files
   - Ensure "walkanywhereTests" target is checked
   - Click "Add"

## Option 2: Run Tests via Command Line

Once the target is added, you can run tests with:

```bash
xcodebuild test -project walkanywhere.xcodeproj -scheme walkanywhere -destination 'platform=iOS Simulator,name=iPhone 17'
```

## What the Tests Cover

### Bug #1: Missing Steps After App Close
**Test:** `testBugScenario_MissingStepsAcrossDayBoundary`
- Simulates: 3100 steps tracked, app closed, user actually did 5800
- Verifies: Backfill updates from 3100 to 5800
- Verifies: Next day correctly tracks all new steps

### Bug #2: Steps Lost on Same Day Reopening
**Test:** `testSameDayReopening_PreservesSteps`
- Simulates: App opened with 1000 steps, walks to 2500, app closed, reopens at 3500
- Verifies: All 3500 steps are tracked (none lost)
- Verifies: startingSteps doesn't recalculate on same day

### Other Critical Scenarios
- **Route switching** without transferring steps
- **Day boundary crossing** with proper recalculation
- **Multiple app sessions** in one day
- **Persistence** across app restarts

## Running Specific Tests

```bash
# Run all tests
xcodebuild test -project walkanywhere.xcodeproj -scheme walkanywhere -destination 'platform=iOS Simulator,name=iPhone 17'

# Run only RouteManager tests
xcodebuild test -project walkanywhere.xcodeproj -scheme walkanywhere -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:walkanywhereTests/RouteManagerTests

# Run only the bug scenario test
xcodebuild test -project walkanywhere.xcodeproj -scheme walkanywhere -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:walkanywhereTests/StepTrackingTests/testBugScenario_MissingStepsAcrossDayBoundary
```

## Expected Results

All tests should pass ✅ with the fixes in place. If any test fails, it indicates the bug fix isn't working correctly.
