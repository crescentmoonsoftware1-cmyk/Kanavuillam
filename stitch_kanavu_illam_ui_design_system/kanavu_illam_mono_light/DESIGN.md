---
name: Kanavu Illam Mono Light
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#444748'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#747878'
  outline-variant: '#c4c7c7'
  surface-tint: '#5f5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1c1b1b'
  on-primary-container: '#858383'
  inverse-primary: '#c9c6c5'
  secondary: '#5e5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e1dfdf'
  on-secondary-container: '#626262'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1c1b1b'
  on-tertiary-container: '#858383'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e5e2e1'
  primary-fixed-dim: '#c9c6c5'
  on-primary-fixed: '#1c1b1b'
  on-primary-fixed-variant: '#474646'
  secondary-fixed: '#e4e2e2'
  secondary-fixed-dim: '#c7c6c6'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#464747'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c9c6c5'
  on-tertiary-fixed: '#1c1b1b'
  on-tertiary-fixed-variant: '#474646'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Syne
    fontSize: 56px
    fontWeight: '500'
    lineHeight: 64px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Syne
    fontSize: 38px
    fontWeight: '500'
    lineHeight: 46px
    letterSpacing: -0.015em
  display-md:
    fontFamily: Syne
    fontSize: 44px
    fontWeight: '500'
    lineHeight: 52px
    letterSpacing: -0.02em
  display-md-mobile:
    fontFamily: Syne
    fontSize: 32px
    fontWeight: '500'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Syne
    fontSize: 32px
    fontWeight: '500'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Syne
    fontSize: 26px
    fontWeight: '500'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Syne
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
    letterSpacing: -0.005em
  headline-sm:
    fontFamily: Syne
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
    letterSpacing: -0.005em
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.005em
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 1rem
  margin: 3rem
  margin-mobile: 1.25rem
  margin-tablet: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

A clean, premium, architectural look in pure white, black and neutral grey. Crisp white cards float over a pale grey canvas, with one black feature element per screen. There is NO green, blue, orange or any accent color.

- **Composition rule**: Screens are compositions, not grids. Cards are full width and stacked. Never place two cards side by side.
- **Scrolling**: Every screen fits one viewport. No page scrolling.
- **Copy**: Titles of 1 to 2 words and captions of 2 to 4 words. No taglines or helper sentences.
- **Imagery**: 3D renders are monochrome "clay models" in white and light grey. No colored plants, water or sky.

## Colors

- **Page background**: `#F4F4F4`
- **Cards and sheets**: `#FFFFFF`
- **Black** (`#0A0A0A`): primary buttons, titles, active states, progress arcs, the active page dot
- **Secondary text, captions, placeholders**: `#6B6B6B` (about 4.8:1 on `#F4F4F4`)
- **Soft fills** (icon circles, progress tracks, active nav pill, inactive dots): `#EAEAEA`
- **Dividers and couplers**: `#DADADA`
- **Semantic error** (`#B3261E`): the only non-neutral color, reserved for errors, failed uploads and destructive prompts.

## Typography

- **Syne (Medium 500)**: brand name, screen titles, card titles, large figures.
- **Inter (400 and 600)**: inputs, captions, buttons, labels.
- Minimum text size is 12px.

## Layout & Spacing

- **Mobile (<640px)**: single column, 20px side margins, bottom-anchored actions.
- **Tablet / Desktop (≥640px)**: content centered at a max width of 560px. The floating nav becomes a left icon rail.
- Gaps between blocks are 16 to 24px. No large empty bands.
- The brand block starts about 64px below the status bar.

## Elevation & Depth

- **Canvas**: `#F4F4F4`.
- **Cards**: `#FFFFFF` with `0 8px 24px rgba(10, 10, 10, 0.06)`. No outlines.
- **Floating nav**: solid `#FFFFFF` (no blur) with `0 12px 32px rgba(10, 10, 10, 0.08)`.
- **Modals and sheets**: a `#0A0A0A` scrim at 24%, and a white body with `0 24px 48px rgba(10, 10, 10, 0.12)`.

## Shapes

- Cards and the hero: 28px radius. Inputs: 16px. Bottom sheets: 32px top corners.
- Buttons, chips, badges and the nav: full pill.
- Icon buttons: 44x44, 12px radius.

## Components

### Buttons
- **Primary**: `#0A0A0A` fill, white label (Inter 600, 14px), 52px tall, full pill, with an optional small white circle holding a black arrow. Pressed: 90% opacity.
- **Secondary**: `#EAEAEA` fill, black label.
- **Outline**: transparent with a `1px solid #DADADA`, black label.
- **Disabled**: `#EAEAEA` fill, `#8A8A8A` label.
- **Ghost / text link**: black text, underlined for legal links.

### Cards
- White, 28px radius, 20px padding, soft shadow, no border.

### Inputs
- White fill, `1px solid #DADADA`, 16px radius, 56px tall. Text `#0A0A0A`, placeholder `#6B6B6B`.
- Focus: a `1.5px` `#0A0A0A` border, with no glow.
- Error: a `1.5px` `#B3261E` border, and one short message below the field in `#B3261E`.

### Chips and badges
- Status badges: `#EAEAEA` fill, `#0A0A0A` text, full pill.
- Selected filter chip: `#0A0A0A` fill, white text. Unselected: white with a `1px solid #DADADA`.

### Checkbox and radio
- 20px, white with a `1.5px solid #8A8A8A` border. Checked: `#0A0A0A` fill with a white check.

### Progress
- Track `#EAEAEA`, arc `#0A0A0A`. Not started: a dashed `#DADADA` ring with a small black "+" circle.

### Workflow train (Home)
- 4 compartment cards (Upload, Pay, Reports, Download): white, 28px radius, a number badge (`#0A0A0A` fill, white number), a 40px outlined icon in an `#EAEAEA` circle, a Syne 22 title and a `#6B6B6B` caption.
- The active card is at 100%, and neighbours peek about 48px at 55% opacity.
- Dots: the active one is a black pill 24x8, the inactive ones are 8x8 in `#EAEAEA`.
- Auto-advance every 5.5s with a 600ms ease-in-out slide. Reduce-motion uses a cross-fade.

### Hero upload card (Home)
- White card, the "Your Plan" title, "JPG, PNG, PDF" caption, a black "Upload Plan" pill, and a clay-model house inside a progress ring. The whole card is one upload tap target.

### Bottom navigation
- A floating solid white pill with 3 items, icon over label: Home, History, Profile. The active item sits in an `#EAEAEA` pill with a black icon and label. Inactive items are `#6B6B6B`.

### Lists (History, Profile, Reports)
- Rows sit in ONE white card with `#EAEAEA` dividers. Icons sit in 44px `#EAEAEA` circles. Titles are Syne 16 in black, and captions are Inter 13 in `#6B6B6B`.