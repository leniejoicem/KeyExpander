# KeyExpander

KeyExpander is a macOS text expansion app for saving reusable snippets and expanding them globally as you type.

## Features

- global text expansion from custom triggers
- snippet categories for organization
- enabled/disabled snippet behavior
- case-sensitive or case-insensitive matching
- usage count and last updated stats
- multiline snippet support with preserved spacing
- light and dark theme options

## Built With

- Swift
- SwiftUI
- SQLite.swift
- Xcode

## Requirements

- macOS
- Xcode 15 or later recommended

## Permissions

KeyExpander requires these macOS permissions to work correctly:

- Accessibility
- Input Monitoring

You can grant both from:

`System Settings > Privacy & Security`

## Getting Started

1. Open `KeyExpander.xcodeproj` in Xcode.
2. Select the `KeyExpander` scheme.
3. Build and run the app.
4. Grant Accessibility and Input Monitoring when prompted.

## How It Works

1. Create a snippet with a trigger such as `;sig`.
2. Add the text you want to expand.
3. Type the trigger in another app.
4. Press `Space` or `Return` to expand it.

## Local Data

The app stores its database locally in your user Application Support folder.

Example:

`~/Library/Application Support/keyexpander.sqlite`

This local database is not part of the repository.

## Project Structure

- `App/` app entry point
- `UI/` SwiftUI views and presentation
- `ViewModels/` app state and coordination
- `Engine/` text expansion logic
- `Listener/` global keyboard listener
- `Repositories/` database access
- `Database/` SQLite setup and migrations
- `Models/` app data models

## Notes

- Local SQLite files are ignored by `.gitignore`.
- The app currently targets desktop macOS usage.

