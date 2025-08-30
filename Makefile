SIM ?= 'platform=iOS Simulator,name=iPad (A16)'

.PHONY: gen build test lint ci

gen:
	xcodegen generate

build:
	xcodebuild -scheme Caligraphy -destination $(SIM) build

test:
	xcodebuild -scheme Caligraphy -destination $(SIM) test

lint:
	swiftlint

ci: gen lint build test

