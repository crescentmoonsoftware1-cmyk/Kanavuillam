# 🏠 Kanavu Illam (Kanavuillam) — AI-Powered Smart Home Design & Estimation Platform

> **Kanavu Illam** (Dream House) is an AI-driven architectural design, 3D visualization, blueprint estimation, and Vastu compliance platform. It bridges home builders, architects, and structural engineers with automated estimations, custom elevations, and interactive 3D floor plan viewers.

---

## ✨ Features

- 📐 **Smart Blueprint & Dimension Parsing**: Upload floor plans to automatically extract room dimensions, wall boundaries, and layout features using AI/Computer Vision.
- 🧱 **Material & Structural Estimation**: Dynamic cost calculator for cement, steel, bricks, sand, paint, doors, windows, and labor estimation based on real-time market rates.
- 🏛️ **3D Interactive Viewer & Elevation Designs**: Interactive 3D visualization for floor plans, customized room elevations (Modern, Tropical, Traditional), and custom door/window selections.
- 🧭 **Vastu Compliance Engine**: AI-assisted Vastu Shastra analysis for room positioning and layout alignment.
- 📄 **Automated PDF Report Generation**: Export complete estimation reports, structural specs, and breakdown summaries into downloadable PDF files.
- 💳 **Secure Payment & Subscriptions**: Integrated Razorpay payment processing for premium reports and architectural blueprints.

---

## 🛠️ Tech Stack

### **Frontend**
- **Framework**: [Flutter](https://flutter.dev/) (Web & Cross-Platform)
- **State & UI**: Custom Responsive Widgets, Interactive Canvas, Dynamic Glassmorphism UI
- **PDF Engine**: `pdf` / `printing` Flutter packages

### **Backend & AI Engine**
- **API Server**: Node.js with Express 5
- **Database**: [Supabase](https://supabase.com/) (PostgreSQL & Storage)
- **AI & Vision**:
  - Python (OpenCV, PyTorch YOLO room models)
  - Google Gemini AI (`@google/generative-ai`)
- **Payments**: Razorpay SDK

---

## 📁 Repository Structure

```text
Kanavuillam/
├── backend/
├── frontend/
│   ├── assets/
│   │   ├── images/         # Textures, backgrounds, and model icons
│   │   └── viewer/         # 3D WebGL viewer scripts & assets
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/        # Auth, Blueprint, Estimation, Vastu, Viewer, Profile, Shell
│   │   ├── services/       # API Service, PDF Service
│   │   └── widgets/        # Custom Material & Door/Window Selector components
│   └── pubspec.yaml
└── README.md
```


