#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the WidgetKit extension target to the iOS project.
#
# A widget extension cannot be added by editing files alone: it needs a build
# target, an embed-app-extension build phase on the Runner, and a handful of
# build settings wired to the shared App Group. Xcode's project file is only
# safely editable through the `xcodeproj` gem, which ships with CocoaPods, so
# this script is the reproducible way to do it.
#
# It is idempotent. Running it twice leaves the project unchanged, which matters
# because a partially-applied setup is far harder to diagnose than a clean
# re-run.
#
# Usage:  ruby scripts/ios/add_widget_target.rb
#
# Requirements: macOS, Xcode command line tools, CocoaPods installed
#   (`sudo gem install cocoapods` or `brew install cocoapods`)

require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
IOS_DIR = File.join(ROOT, 'ios')
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')
WIDGET_DIR = File.join(IOS_DIR, 'StandUpWidget')
ASSET_CATALOG = File.join(WIDGET_DIR, 'Assets.xcassets')

WIDGET_TARGET_NAME = 'StandUpWidget'
WIDGET_BUNDLE_ID = 'com.healthwellness.standupApp.StandUpWidget'
APP_GROUP = 'group.com.healthwellness.standupApp'

# WidgetKit interactive buttons and the `.containerBackground` modifier both
# need iOS 17. The app itself still supports 15, so only this target is raised.
WIDGET_DEPLOYMENT_TARGET = '17.0'

SOURCES = %w[
  CSPHStandUpWidget.swift
  StandUpIntents.swift
  StandUpProvider.swift
  StandUpWidgetView.swift
  WidgetPayload.swift
  WidgetStyle.swift
].freeze

def die(message)
  warn "error: #{message}"
  exit 1
end

def note(message)
  puts "  #{message}"
end

# Warnings go to stderr so they are visible even when the script's output is
# being filtered, and never abort the run.
def warn_once(message)
  warn "  WARNING: #{message}"
end

def section(title)
  puts "\n#{title}"
  puts '-' * title.length
end

# ── Preflight ────────────────────────────────────────────────────────────────

section 'Checking prerequisites'

die "not a macOS host (widget targets need Xcode)" unless RUBY_PLATFORM.include?('darwin')

begin
  require 'xcodeproj'
rescue LoadError
  die "the xcodeproj gem is missing. Install CocoaPods: brew install cocoapods"
end

die "cannot find #{PROJECT_PATH}" unless File.exist?(PROJECT_PATH)
die "cannot find #{WIDGET_DIR}" unless File.directory?(WIDGET_DIR)

missing = SOURCES.reject { |f| File.exist?(File.join(WIDGET_DIR, f)) }
die "missing widget sources: #{missing.join(', ')}" unless missing.empty?

info_plist = File.join(WIDGET_DIR, 'Info.plist')
entitlements = File.join(WIDGET_DIR, 'StandUpWidget.entitlements')
die "missing #{info_plist}" unless File.exist?(info_plist)
die "missing #{entitlements}" unless File.exist?(entitlements)
die "missing #{ASSET_CATALOG}" unless Dir.exist?(ASSET_CATALOG)

note 'sources present'
note 'project present'
note 'asset catalog present'

# ── Open project ─────────────────────────────────────────────────────────────

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
die 'no Runner target found' if runner.nil?

section 'Adding the widget extension target'

existing = project.targets.find { |t| t.name == WIDGET_TARGET_NAME }
if existing
  note "target #{WIDGET_TARGET_NAME} already exists; reusing it"
  widget = existing
else
  widget = project.new_target(
    :app_extension,
    WIDGET_TARGET_NAME,
    :ios,
    WIDGET_DEPLOYMENT_TARGET,
    nil,
    :swift
  )
  note "created target #{WIDGET_TARGET_NAME}"
end

# ── Sources ──────────────────────────────────────────────────────────────────

group = project.main_group.find_subpath(WIDGET_TARGET_NAME, true)

# The group's path has to be set explicitly. Without it Xcode resolves every
# relative file reference against the *project* directory, so a reference to
# `CSPHStandUpWidget.swift` becomes ios/CSPHStandUpWidget.swift instead of
# ios/StandUpWidget/CSPHStandUpWidget.swift, and the build fails with
# "Build input files cannot be found". Setting it here is what makes every
# reference below correct.
group.set_path(WIDGET_TARGET_NAME) if group.path.nil?

# Fail before touching the project if a source is missing, so a renamed file
# produces a clear message instead of a dozen confusing Xcode errors later.
SOURCES.each do |name|
  path = File.join(WIDGET_DIR, name)
  die "missing source file #{path}" unless File.exist?(path)
end

existing_names = widget.source_build_phase.files_references.compact.map(&:display_name)

SOURCES.each do |name|
  if existing_names.include?(name)
    note "#{name} already referenced"
    next
  end
  ref = group.files.find { |f| f.display_name == name }
  ref ||= group.new_reference(name)
  widget.add_file_references([ref])
  note "added #{name}"
end

# Resources: the Info.plist is referenced through the build settings, not as a
# resource, so it must not end up in a copy-resources phase. The asset catalog
# does have to be copied, because `Image("standup_logo")` in the widget view
# resolves against the extension's own bundle.
if widget.resources_build_phase.files_references.any? { |f| f.display_name == 'Assets.xcassets' }
  note 'Assets.xcassets already in the resources phase'
elsif Dir.exist?(ASSET_CATALOG)
  catalog_ref = group.new_reference('Assets.xcassets')
  widget.add_resources([catalog_ref])
  note 'added Assets.xcassets (app logo)'
else
  die "missing #{ASSET_CATALOG}; the widget view references Image(\"standup_logo\")"
end

# Referencing the Info.plist as a resource as well would make iOS treat it as a
# nested plist, which Xcode rejects at validation.
if widget.resources_build_phase.files_references.any? { |f| f.display_name == 'Info.plist' }
  note 'Info.plist excluded from resources'
end

# ── Build settings ───────────────────────────────────────────────────────────

section 'Configuring build settings'

widget.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'StandUpWidget/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'StandUpWidget/StandUpWidget.entitlements'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = WIDGET_DEPLOYMENT_TARGET
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  # The extension ships inside the app bundle, so it must not be codesigned as a
  # standalone product or the embed phase rejects it.
  s['SKIP_INSTALL'] = 'YES'
  s['CODE_SIGNING_ALLOWED'] = 'YES'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  note "#{config.name}: bundle id, entitlements, Info.plist, deployment target"
end

# ── App Group on the app ─────────────────────────────────────────────────────

section 'Wiring the App Group into the Runner target'

runner_entitlements = File.join(IOS_DIR, 'Runner', 'Runner.entitlements')
unless File.exist?(runner_entitlements)
  die "missing #{runner_entitlements}; the app and widget must share the App Group"
end

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  note "#{config.name}: CODE_SIGN_ENTITLEMENTS -> Runner/Runner.entitlements"
end

# ── Embed phase ──────────────────────────────────────────────────────────────

section 'Embedding the extension in the app bundle'

embed = runner.copy_files_build_phases.find do |phase|
  phase.name == 'Embed Foundation Extensions'
end

if embed.nil?
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  note 'created Embed Foundation Extensions phase'
else
  note 'Embed Foundation Extensions phase already present'
end

already_embedded = embed.files_references.any? { |f| f.display_name == "#{WIDGET_TARGET_NAME}.appex" }
unless already_embedded
  build_file = embed.add_file_reference(widget.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  note "embedded #{WIDGET_TARGET_NAME}.appex"
end

# Extensions must be embedded before the app is signed.
runner.build_phases.delete(embed)
runner.build_phases << embed

# ── Dependency ───────────────────────────────────────────────────────────────

section 'Adding the build dependency'

unless runner.dependencies.any? { |d| d.target == widget }
  runner.add_dependency(widget)
  note 'Runner now depends on the widget target'
else
  note 'dependency already present'
end

# ── Scheme ───────────────────────────────────────────────────────────────────

section 'Creating a shared scheme'

scheme_dir = File.join(IOS_DIR, 'Runner.xcodeproj', 'xcshareddata', 'xcschemes')
Dir.mkdir(scheme_dir) unless Dir.exist?(scheme_dir)
scheme_path = File.join(scheme_dir, "#{WIDGET_TARGET_NAME}.xcscheme")

if File.exist?(scheme_path)
  note 'shared scheme already exists'
else
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(widget)

  # Pre-actions make the Flutter toolchain run first, otherwise the extension is
  # built against a stale Generated.xcconfig and fails to find the app's
  # headers. This is the same trick Flutter's own template uses.
  #
  # Two things have bitten this before, so it is best-effort rather than fatal:
  # a scheme pre-action lives on the scheme's *build action* (XCScheme has no
  # #add_pre_action), and a freshly constructed BuildAction has a nil
  # #pre_actions until something assigns it. Neither should stop the target
  # itself from being created, which is what the caller actually needs.
  begin
    scheme.build_action.pre_actions ||= []
    scheme.build_action.pre_actions << Xcodeproj::XCScheme::PreAction.new(
      'Run Flutter Build',
      :shell_script,
      '/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build'
    )
  rescue StandardError => e
    warn_once "could not add the Flutter pre-action to the scheme (#{e.class}: #{e.message})"
    warn_once 'the target is still created; if the build later reports a stale'
    warn_once 'Generated.xcconfig, add the pre-action in Xcode by hand.'
  end

  scheme.save_as(PROJECT_PATH, WIDGET_TARGET_NAME, true)
  note "created shared scheme #{WIDGET_TARGET_NAME}"
end

# ── Persist ──────────────────────────────────────────────────────────────────

section 'Saving'

project.save
note 'project saved'

puts <<~SUMMARY

  #{WIDGET_TARGET_NAME} target installed.

  Next steps
  -----------
  1. pod install --repo-update   (from ios/)
  2. Open ios/Runner.xcworkspace in Xcode.
  3. Select the Runner target -> Signing & Capabilities -> + Capability ->
     App Groups, and add #{APP_GROUP}
     (the entitlements files are already written; this step registers the group
     with the developer portal, which Xcode can only do with your team).
  4. Select the #{WIDGET_TARGET_NAME} target -> Signing & Capabilities ->
     + Capability -> App Groups -> #{APP_GROUP}
  5. Set your Development Team on both targets.
  6. Build and run once on a device, then add the widget from the home screen.

SUMMARY
