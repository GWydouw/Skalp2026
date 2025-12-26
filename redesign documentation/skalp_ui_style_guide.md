# Skalp UI Style Guide (Dialog Standard)

This document outlines the visual and behavioral standards established during the perfection of the **SectionBox Manager**. Use these settings to maintain a consistent "Skalp House Style" for future dialogs.

## 1. Colors & Design Tokens

| Token | Value | usage |
| :--- | :--- | :--- |
| **Primary Grey** | `#ebebeb` | Dialog background, toolbar, status bar. |
| **Border Grey** | `#b8b8b8` | Content area main border. |
| **Subtle Border** | `#ccc` | Toolbar divider, header bottom border. |
| **Content Area** | `#ffffff` | White background for lists/trees. |
| **Zebra Stripe** | `#f5f5f5` | Alternate list row color. |
| **Selection Blue** | `#3875d7` | Selected item background. |
| **Hover Blue** | `rgba(56, 117, 215, 0.1)` | Item hover and drag-over highlight. |
| **Text Primary** | `#333333` | Standard labels and header text. |
| **Text Secondary** | `#444444` | Status bar and secondary labels. |
| **Text Tertiary** | `#999999` | Muted labels (e.g., Scale column). |
| **Icon Fill (Grey)** | `#757575` | Standard folder and item icon color. |

## 2. Typography

- **Font Family:** `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`
- **Base Size:** `12px`
- **Muted Size:** `10px` (e.g., italics in list items)
- **Status Size:** `11px`
- **Weights:**
  - `normal` (400) for headers and labels.
  - `600` for "active" or prominent items.

## 3. Layout & Dimensions

- **Toolbar Height:** `38px`
- **Header Height:** `25px`
- **Row Height:** `22px` (matches zebra pattern)
- **Status Bar Height:** `20px` (standard desktop feel)
- **Margins:** `8px` horizontal margin for the content area.
- **Minimized Height (Mac):** `68px` (Title bar + Toolbar).

## 4. Components

### Toolbar

- **Button Spacing:** `8px` gap.
- **Icon Sizing:**
  - Standard buttons: `24px` wrapper, `22px` visual.
  - "+" Add: `18px`.
  - Folder Add: `23px`.
- **Search Field:**
  - Height: `22px`.
  - Border-radius: `4px`.
  - Padding: `padding-left: 24px` (to clear internal 13px icon).

### Tree View / Lists

- **Zebra Pattern:**

  ```css
  background-image: repeating-linear-gradient(to bottom, #ffffff 0px, #ffffff 22px, #f5f5f5 22px, #f5f5f5 44px);
  ```

- **Focus Suppression:** Always use `outline: none !important;` and `-webkit-focus-ring-color: rgba(0,0,0,0)` to avoid browser artifacts like dotted lines.
- **Drag-and-Drop:** Use `rgba(56, 117, 215, 0.1)` background highlight instead of dashed borders.

### Status Bar

- Alignment: Positioned directly below the content area border.
- Text: Normal weight, `11px`, horizontally aligned with the content start.

## 5. Standard Behaviors

1. **Width Synchronization:** Dialog width should remain identical when toggling between minimized and maximized states.
2. **Height Locking:** When minimized, use a `resize` listener to snap the height back to `68px` if the user tries to vertically stretch it.
3. **Global Cleanup:** Implement a global `dragend` and `drop` listener to clear all `.drag-over` highlights regardless of target.
