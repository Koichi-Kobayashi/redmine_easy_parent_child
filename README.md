[English](README.md) | [日本語](README.ja.md)

# Easy Parent Child

A Redmine plugin that allows you to easily set parent-child relationships between tickets using drag & drop.

## Requirements

- Redmine 4.0 or later

## Features

- Intuitive parent-child relationship setting with drag & drop
- Management of multiple parent and child tickets
- Ticket filtering functionality
- Save and reset changes
- Unified design with Redmine standard UI
- **Disconnect parent-child relations**: Disconnect button on child tickets to separate a ticket and its descendants as an independent tree

## Installation

1. Place the plugin in the plugin directory (`plugins/redmine_easy_parent_child`)
2. Restart Redmine
3. Enable the "Easy Parent Child" module in project settings

> **Note**: This plugin only uses Redmine's standard database structure, so no migration is required.

## Usage

### Setting Parent-Child Relationships

1. Select "Easy Parent Child" from the project menu
2. Filter tickets to display using the filter
3. Drag tickets from the left side to the parent or child area on the right side
4. Click the "Save" button to confirm changes

### Disconnecting Parent-Child Relationships

You can disconnect a parent-child relationship by clicking the "Disconnect" button on a child ticket in the tree view.

**How it works:**
- When you click the "Disconnect" button on a child ticket, that ticket and all its descendants are separated as an independent tree
- Example: If you have a relationship A - B - C - D - E, clicking the disconnect button on C will result in:
  - A - B (original tree)
  - C - D - E (separated tree)
- The disconnected ticket becomes a root ticket (has no parent), and all its descendants remain as its children

**Steps:**
1. Find the child ticket you want to disconnect in the tree view (left side)
2. Click the "Disconnect" button on that ticket
3. Confirm the action in the confirmation dialog
4. The relationship will be disconnected and the page will reload to show the updated tree structure

## License

GPL v2