# 🏠 Kanavu Illam (Kanavuillam) — Smart Home Design & Blueprint Estimation Platform

> **Kanavu Illam** (Dream House) is a comprehensive architectural design, interactive 3D visualization, blueprint estimation, and Vastu compliance platform. It empowers home builders, architects, and structural engineers with automated estimations, custom elevations, and interactive floor plan viewers.

---

## ✨ Key Features

- 📐 **Smart Blueprint & Dimension Parsing**: Upload floor plans to seamlessly analyze room dimensions, wall boundaries, and layout features.
- 🧱 **Material & Structural Estimation**: Dynamic cost calculation engine for cement, steel, bricks, sand, paint, doors, windows, and labor based on customizable market rates.
- 🏛️ **3D Interactive Viewer & Elevation Designs**: Interactive 3D floor plan visualizer, room elevation styles (Modern, Tropical, Traditional), and customizable door/window selection tools.
- 🧭 **Vastu Compliance Engine**: Automated Vastu Shastra orientation analysis for room positioning and layout alignment.
- 📄 **Automated PDF Report Generation**: Export detailed estimation reports, structural specifications, and cost summaries as downloadable PDF documents.
- 💳 **Secure Payment Integration**: Integrated Razorpay payment processing for premium architectural reports and estimation blueprints.

---

## 🛠️ Tech Stack

### **Frontend**
- **Framework**: [Flutter](https://flutter.dev/) (Web & Cross-Platform)
- **State & UI**: Custom Responsive Widgets, Interactive Canvas, Dynamic UI Components
- **PDF Engine**: `pdf` / `printing` Flutter packages

### **Backend Engine**
- **API Server**: Node.js with Express
- **Database**: [Supabase](https://supabase.com/) (PostgreSQL & Cloud Storage)
- **Processing Engine**: Python (OpenCV & Image Processing)
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
