---
name: Fidelity Theme
colors:
  surface: '#faf8fe'
  surface-dim: '#dad9df'
  surface-bright: '#faf8fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f8'
  surface-container: '#efedf3'
  surface-container-high: '#e9e7ed'
  surface-container-highest: '#e3e2e7'
  on-surface: '#1a1b1f'
  on-surface-variant: '#544435'
  inverse-surface: '#2f3034'
  inverse-on-surface: '#f1f0f6'
  outline: '#877463'
  outline-variant: '#dac2af'
  surface-tint: '#8b5000'
  primary: '#8b5000'
  on-primary: '#ffffff'
  primary-container: '#e58a18'
  on-primary-container: '#532d00'
  inverse-primary: '#ffb872'
  secondary: '#555f70'
  on-secondary: '#ffffff'
  secondary-container: '#d6e0f4'
  on-secondary-container: '#596374'
  tertiary: '#904d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#e68933'
  on-tertiary-container: '#562c00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcbe'
  primary-fixed-dim: '#ffb872'
  on-primary-fixed: '#2d1600'
  on-primary-fixed-variant: '#6a3c00'
  secondary-fixed: '#d9e3f7'
  secondary-fixed-dim: '#bdc7db'
  on-secondary-fixed: '#121c2b'
  on-secondary-fixed-variant: '#3d4758'
  tertiary-fixed: '#ffdcc3'
  tertiary-fixed-dim: '#ffb77d'
  on-tertiary-fixed: '#2f1500'
  on-tertiary-fixed-variant: '#6e3900'
  background: '#faf8fe'
  on-background: '#1a1b1f'
  surface-variant: '#e3e2e7'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1.5rem
  margin: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

# Brand & Style
This design system is tailored for Kanavu Illam ("dream home"), a mobile app where homeowners upload a 2D floor plan and receive AI plan analysis, 3D, Vastu and cost reports, then pay and download them. The audience is families and first-time home builders who want clarity and confidence, not technical overload.
The visual direction merges Calm Minimalism with Atmospheric Layering. The mood is a quiet architect's studio: cool daylight on slate, soft white sheets, one dark hero moment, and a single warm amber accent sampled directly from the Kanavu Illam logo. The interface is premium, calm and uncluttered, with generous breathing room. Colour is rare, so when amber appears it clearly means "this is the action" or "you are here".

# Colors
The palette balances cool slate neutrality with one intentional logo-derived amber accent.

## Base Canvas & Environmental Surfaces
- Canvas Gradient: The primary screen background is a vertical linear gradient from #E9EEF4 (top) to #D8DFE9 (bottom).
- Card & Sheet Surfaces: #FCFDFF is reserved for elevated containers: workflow cards, bottom sheets, the floating nav bar and dialogs.
- Page Ground Token: #F4F7FB is the flat surface/background token wherever a gradient is not used.

## Inks & Structural Tones
- Deep Ink (#18191D): Titles, the app name and the most important text.
- Structural Slate (#1B212F): The end of the hero gradient, dark sheets and inverse surfaces.
- Steel Binder (#364050): The start of the hero gradient, secondary neutral, ghost borders and secondary buttons.
- Badge Slate (#2E3744): Step-number badges and the upload icon circle.
- Quiet Grey (#8E94A0): Subtitles, inactive nav icons and labels, secondary text. This replaces the old #B0B0B2, which was too faint at 2.1:1.
- Reading Slate (#64748B): Any grey text people must actually read (helper text, descriptions, form hints).

## Functional Accents (Logo Amber)
Sampled from the logo: windows and chimney #FBA73B, #F59528, #EF9633; roof body #DE8329; highlight #FEB652.
- Amber (#E58A18): The primary action colour, active page dot, focus borders, checkmarks and selected states.
- Amber Highlight (#FBA73B): Gradient start, the upload icon ring and active highlights.
- Amber Deep (#B46205): Amber used as text or icon on light backgrounds, surface tint and pressed states.
- Amber Tint (#FDEBCB): Soft amber fills such as selected rows or info chips.
- Amber Gradient: #FBA73B to #E58A18, top-left to bottom-right (135 degrees).
- On-Amber Ink (#1E252D): All text and icons placed on amber. Dark charcoal gives about 5.9:1 contrast. White on amber is only about 2.6:1 and is not allowed.

## Amber Usage Rule
Amber appears only on: the active carousel dot, the upload icon ring, the primary button, the selected nav item, focus borders and checkmarks. It is never used for large fills, body text or decoration.

## Forbidden
No orange-red, purple, blue, brown or pink tints. The earlier reference oranges #F35A08 and #F98933 are retired. All outlines and tonal surfaces stay cool slate.

# Typography
The type system is powered entirely by Plus Jakarta Sans, using its rounded geometric proportions for a friendly yet premium feel. Titles are weight 700, subtitles and body are weight 400.

## Hierarchy & Usage
- Display & Headlines (display-lg, headline-lg, headline-md, headline-sm): Screen titles and card titles in bold with slightly tight tracking. Card titles such as Upload, AI Plan Analysis, Pay, Reports and Download use headline-sm in #18191D.
- Body (body-lg, body-md, body-sm): One-line subtitles in #8E94A0, descriptions and report text. Keep subtitles to a single line.
- Labels (label-lg, label-md, label-sm): label-lg is the button label (16px, bold, #1E252D on amber). label-md is for nav labels and format chips. label-sm is for tiny badges and step numbers.

# Layout & Spacing
The layout is a single-column mobile flow sized for iPhone 390 x 844, portrait. The Home screen fits without scrolling.

## Layout Rhythm
- Outer Shell: A continuous 1.25rem (20px) screen-edge margin.
- Home Order (top to bottom): centred logo (about 64px tall, with the app name below), workflow carousel with page dots, the dark upload hero card, then the floating nav bar.
- Carousel: Horizontally swipeable cards with the next card peeking in from the right to signal swipe. Page dots sit below.
- Density: Vertical rhythm follows 4px multiples (space-xs = 4px, space-sm = 8px, space-md = 16px, space-lg = 24px, space-xl = 32px), with 24px between major blocks.

# Elevation & Depth
Visual hierarchy uses Soft Cool Shadows and Tonal Layering. Shadows are always tinted with dark slate, never black or warm.

## Layering Levels
- Ground (Level 0): The canvas gradient #E9EEF4 to #D8DFE9.
- Cards (Level 1): #FCFDFF surface, 1px border #E9EAEC, shadow 0 12px 32px rgba(27, 33, 47, 0.10).
- Hero (Level 2): Dark gradient #364050 to #1B212F (vertical) with a deeper soft shadow 0 16px 40px rgba(27, 33, 47, 0.22).
- Floating Nav (Level 3): #FCFDFF pill with shadow 0 12px 32px rgba(27, 33, 47, 0.12), floating above the bottom edge with a margin.
- Amber Glow: The primary button carries 0 8px 24px rgba(229, 138, 24, 0.35).

# Shapes
The interface embraces a Soft, Pill-Forward shape language.
- Cards & Bottom Sheets: rounded-lg (1.75rem / 28px).
- Hero Card & Nav Bar: rounded-xl (2rem / 32px).
- Buttons, Chips, Dots, Step Badges: fully rounded (rounded-full, pill or circle).
- Inputs: rounded-md (1rem / 16px).

# Components
## Buttons
- Primary CTA: Full-width pill, 56px tall, amber gradient (#FBA73B to #E58A18, 135 degrees), label and arrow icon in #1E252D, 16px bold, amber glow shadow. Pressed state shifts toward #B46205. Disabled state uses #D8DFE9 fill with #8E94A0 text.
- Secondary: Fill #1B212F, white text, pill shape, no glow. Used for downloads and confirmations.
- Ghost Action: Transparent background, 1px border #364050 at 20% opacity, text #18191D, pill shape.

## Workflow Cards (Carousel)
- #FCFDFF surface, 28px radius, 1px #E9EAEC border, soft shadow.
- Bold title in #18191D, one-line subtitle in #8E94A0.
- Round step-number badge top right: #2E3744 circle with a white number.

## Page Dots
- Active: amber pill #E58A18. Inactive: small circles #D8DFE9.

## Hero Upload Card
- Gradient #364050 to #1B212F, 32px radius.
- Centre upload icon: #2E3744 circle, white cloud-upload icon, thin amber ring #FBA73B.
- Title "Upload 2D Floor Plan" in white bold. Subtitle in white at 70% opacity.
- Format chips (JPG, PNG, PDF, MAX 25MB): white at 12% opacity fill, white text, pill shape.
- Primary button "Select Floor Plan" at the bottom.

## Bottom Navigation
- Floating #FCFDFF pill with 32px radius and three items: Home, History, Profile.
- Selected item: amber gradient circle with a #1E252D icon.
- Unselected items: #8E94A0 icon and label.

## Chips & Toggles
- Inactive Chip: #FCFDFF surface, 1px border #E2E8F0, text #364050, pill shape.
- Active Chip: Filled #1B212F, text #FCFDFF, with a small amber #E58A18 indicator dot.

## Inputs
- #FCFDFF ground, 1px border #E2E8F0, 16px radius, typing ink #18191D, placeholder #8E94A0.
- Focus state: 1.5px border #E58A18, no outer glow ring.
- Error state: border and helper text #BA1A1A.

## Checkboxes & Selection Controls
- 20px squares with 6px corners. Inactive: 1.5px outline #94A3B8, empty fill.
- Checked: solid #E58A18 fill with a #1E252D checkmark.

## Logo Usage
- Keep the logo exactly as provided, about 64px tall and centred, with "Kanavu Illam" in #18191D below.
- Show the logo only on the light page background, never on the dark hero or on amber.

# Do & Don't
### Do
- Keep amber rare and meaningful.
- Use dark charcoal #1E252D on amber.
- Use pill shapes for actions and 28px to 32px radii for cards.
- Use soft slate-tinted shadows and leave generous whitespace.

### Don't
- Don't use #F35A08, #F98933 or any orange-red.
- Don't put white text on amber.
- Don't use warm brown or pink outlines.
- Don't use purple or blue.
- Don't suppress shadows or use 8px button corners.
- Don't add new text, illustrations or sections beyond the brief.