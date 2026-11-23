set shell := ["bash", "-euo", "pipefail", "-c"]

workspace := "Mactrix.xcworkspace"
scheme := "Mactrix"
destination := "platform=macOS"
xcodebuild := "xcodebuild -workspace " + workspace + " -scheme " + scheme + " -destination '" + destination + "'"

# Pipe xcodebuild output through xcbeautify when it is installed.
pretty := if `xcbeautify --version >/dev/null 2>&1 && echo yes || true` == "yes" { "| xcbeautify" } else { "" }

# List available recipes
default:
    @{{ just_executable() }} --list

# Build the app (Debug)
build:
    {{ xcodebuild }} build {{ pretty }}

# Build and launch the app (Debug)
run: build
    open "$({{ xcodebuild }} -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{dir=$2} / FULL_PRODUCT_NAME = /{name=$2} END{print dir "/" name}')"

# Run all tests in the test plan
test:
    {{ xcodebuild }} test {{ pretty }}

# Run a single test target, class or method (e.g. UtilsTests or UtilsTests/Suite/testName)
test-only target:
    {{ xcodebuild }} test -only-testing:{{ target }} {{ pretty }}

# Remove build products for the scheme
clean:
    {{ xcodebuild }} clean {{ pretty }}

# Format all Swift sources in place
fmt:
    git ls-files -z '*.swift' | xargs -0 xcrun swift-format format --in-place --parallel

# Check formatting without changing files
fmt-check:
    git ls-files -z '*.swift' | xargs -0 xcrun swift-format lint --strict --parallel

# Run the static analyzer
analyze:
    {{ xcodebuild }} analyze {{ pretty }}

# Run the same build, analyze and test steps as CI
ci: build analyze test

# Regenerate the bundled emoji catalog resources
emoji-gen:
    cd Packages/EmojiCatalog && swift run generate-emoji-catalog

# Verify the emoji catalog resources are up to date (needs network)
emoji-check:
    cd Packages/EmojiCatalog && swift run generate-emoji-catalog --check

# Run the EmojiCatalog package tests
emoji-test:
    cd Packages/EmojiCatalog && swift test

# Build a Release app and install it to /Applications
install-release:
    {{ xcodebuild }} build -configuration Release MACTRIX_GIT_COMMIT="$(git rev-parse HEAD)" {{ pretty }}
    app="$({{ xcodebuild }} -configuration Release -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{dir=$2} / FULL_PRODUCT_NAME = /{name=$2} END{print dir "/" name}')"; \
    if pgrep -xq Mactrix; then osascript -e 'quit app "Mactrix"'; sleep 1; fi; \
    rm -rf /Applications/Mactrix.app; \
    ditto "$app" /Applications/Mactrix.app; \
    echo "Installed /Applications/Mactrix.app"
