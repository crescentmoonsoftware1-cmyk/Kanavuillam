class LegalTexts {
  static const String termsAndConditions = '''
# Terms and Conditions for Kanavu Illam

Effective Date: October 27, 2026

Welcome to Kanavu Illam, an architectural planning software application operated by Kanavu Illam Technologies, Tamil Nadu, India ("we", "our", or "us"). By accessing, installing, or using our mobile application or web services, you agree to be bound by these Terms and Conditions.

## 1. Eligibility & User Accounts
* You must be at least 18 years of age to enter into a legally binding contract under the Indian Contract Act, 1872.
* By using this service, you represent and warrant that you meet this age requirement.
* You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account.

## 2. Description of Services & Computer-Vision Disclaimer
Kanavu Illam provides automated architectural analysis tools, including 2D-to-3D parametric CAD modeling, traditional Tamil Vastu rule compliance scoring, and preliminary civil structural and cost estimations.

**Important Accuracy Disclaimer:**
Floor plans are read automatically using computer-vision software (including trained YOLO contour detection and EasyOCR models), which may misread labels, hand-drawn lines, walls, or dimensions. Users must manually verify all dimensions, room boundaries, and site orientations before relying on any output.

* **Vastu Compliance:** Vastu scoring follows traditional cultural rule systems and is provided purely for informational and cultural reference. It does not constitute licensed architectural design, civil engineering, or legal advice.
* **Cost Estimations (BOQ):** Material prices, labor costs, and rate breakdowns are indicative planning estimates based on regional benchmarks and may vary depending on local suppliers, site conditions, and market fluctuations.
* **Structural Guidelines:** Structural assessments and column/beam sizing are preliminary planning guidelines calculated based on commonly used Indian Standard planning formulas (IS 456 and IS 1893 conventions). They do not substitute for on-site geotechnical soil testing, formal municipal building approvals, or certified drawings signed by a licensed structural engineer.

## 3. Pricing, Deliverables & Refund Policy
* **Pricing:** Access to generate complete architectural deliverables is ₹500 per floor plan scan, inclusive of applicable taxes.
* **Payments:** All transactions are processed securely through RBI-authorized payment aggregators (Razorpay). We do not store sensitive payment card details or UPI PINs on our servers.
* **Non-Refundable Computational Processing:** Fees paid cover immediate computational server execution and customized PDF compilation. Once analysis has commenced and deliverables are generated, payments are strictly non-refundable.
* **Technical Failure & One Free Re-try:** In the rare event of a verified technical failure (such as a pipeline crash, system error, or failure to deliver the final PDF report), cash refunds are not issued. If your report fails to generate or deliver due to a technical error, contact support@kanavuillam.com within 7 days of purchase with your transaction Order ID. Upon quick verification, our support team will enable **one free re-processing of the same floor plan** at zero additional charge.

## 4. User Content & Intellectual Property
* Users retain ownership of their uploaded architectural sketches and blueprints.
* Kanavu Illam Technologies retains all rights, title, and interest in and to the application, software, algorithms, 3D parametric viewer, branding, UI designs, and underlying code.
* Upon successful generation and payment, you are granted a perpetual, personal, non-exclusive license to view, download, print, and share your generated PDF report.

## 5. Limitation of Liability
To the maximum extent permitted under applicable Indian law, Kanavu Illam Technologies, its founders, and employees shall not be liable for any indirect, incidental, punitive, or consequential damages, construction defects, contractor disputes, foundation settlement, structural collapse, or cost overruns resulting from the use of or reliance on automated reports.

**Liability Cap:**
In all circumstances, our maximum aggregate liability arising out of or related to your use of the application or reports shall be strictly capped at the amount actually paid by you for the specific service (maximum ₹500).

## 6. Termination & Acceptable Use
You agree not to misuse the platform, reverse engineer the computer-vision algorithms, upload malicious or unlawful content, or attempt unauthorized access to our servers. We reserve the right to suspend or terminate accounts that violate these terms.

## 7. Governing Law & Jurisdiction
These Terms shall be governed by and construed in accordance with the laws of the Republic of India. Any disputes, claims, or controversies arising out of or relating to these Terms or the use of the service shall be subject to the exclusive jurisdiction of the competent courts in Tamil Nadu, India.

## 8. Contact Information
For questions or assistance regarding these terms:
* **Entity:** Kanavu Illam Technologies
* **Address:** Tamil Nadu, India
* **Email:** support@kanavuillam.com
''';

  static const String privacyPolicy = '''
# Privacy Policy for Kanavu Illam

Effective Date: October 27, 2026

Kanavu Illam ("we", "our", or "us"), operated by Kanavu Illam Technologies, Tamil Nadu, India, is committed to safeguarding your personal data and privacy. This Privacy Policy details how we collect, process, store, and protect your information across our mobile application and web services in full compliance with the Digital Personal Data Protection Act, 2023 (DPDP Act), the Information Technology Act, 2000, the SPDI Rules, 2011, and Google Play Developer Data Safety Policies.

## 1. Information We Collect and Purpose of Processing
* **Account Credentials:** Full name and email address provided via Google Sign-In (OAuth) or Supabase authentication, used strictly to create, authenticate, and manage your account.
* **Uploaded Floor Plan Images:** 2D architectural blueprint drawings or sketches uploaded by you. These are used solely for automated geometric contour detection, room boundary segmentation, and text reading.
* **Derived Architectural Project Data:** 3D parametric CAD coordinates, room dimensions, traditional Tamil Vastu rule scores, estimated material bill of quantities (BOQ), and preliminary structural guidance generated from your uploads. These are saved to your account so you can view, review, and export them at any time in your History tab.
* **Payment and Transaction Records:** When you unlock premium deliverables, our payment partner (Razorpay) provides us with the transaction ID, order ID, payment status, timestamp, and amount. These records are used strictly for order fulfillment, fraud prevention, accounting, and statutory tax (GST) compliance. We never receive, process, or store credit/debit card numbers, CVVs, or UPI PINs on our servers.
* **Technical Telemetry & Device Logs:** IP address, device operating system version, and standard access logs collected ephemerally for rate limiting, DDoS defense, and server health diagnostics.
* **Local Storage:** Authentication session tokens and language preferences (English/Tamil) stored locally on your device via secure application storage (SharedPreferences).

## 2. Immediate Zero-Storage Architecture for Raw Blueprints
Uploaded floor plan image files are temporarily stored on secure server disk strictly during automated processing by computer-vision and OCR models (trained YOLO object detection and EasyOCR). Immediately upon completing the analysis, the raw image files are permanently unlinked and erased from the server disk. No raw floor plan image files are retained on our servers.

## 3. Project Results & Cloud Data Storage
Unlike raw blueprint images, the derived architectural models (room polygons, 3D vectors, Vastu scores, and cost estimations) are stored securely in our cloud database (Supabase) under your unique user ID. This enables you to access your projects across app sessions in your History screen. These project results remain stored under your account until you choose to delete them or permanently delete your account.

## 4. Third-Party Service Providers & Data Transfers
We work with trusted infrastructure providers that adhere to industry security standards (ISO 27001 / SOC 2):
* **Supabase Inc.:** Cloud database hosting, user authentication, and Row Level Security (RLS).
* **Railway Corp.:** Secure cloud backend hosting and API pipeline execution.
* **Vercel Inc.:** Hosting our static web portals and compliance documentation.
* **Google LLC:** Google OAuth 2.0 user authentication.
* **Razorpay Software Private Limited:** RBI-authorized payment processing. All payment transaction data is localized and stored in India in compliance with Reserve Bank of India (RBI) mandates.
* **OpenRouter Inc.:** Ephemeral text queries for live regional construction material prices. Your floor plan drawings, personal identifiers, and private account details are never sent to OpenRouter or external LLMs.

## 5. Data Retention & Account Deletion Policy
We retain your personal profile and project history only for as long as your account is active:
* **User-Initiated Deletion:** You have the absolute right to delete your account at any time. You can trigger deletion within the app under Profile > Delete Account, or via our public web deletion page.
* **What is Purged:** Deleting your account immediately and permanently removes your profile, authentication credentials, project records, 3D models, and history logs from our database.
* **Statutory Retention Exception:** Anonymized payment transaction logs are retained strictly for the statutory duration required by Indian tax, GST, and financial audit regulations.

## 6. User Rights (DPDP Act, 2023)
In accordance with the Digital Personal Data Protection Act, you possess the right to:
* Access a summary of your personal data processed by us.
* Request correction or updating of inaccurate or incomplete personal data.
* Withdraw your consent at any time and request erasure of your data.
* Nominate another individual in accordance with applicable legal provisions.

## 7. Age Eligibility (18+ Requirement)
Kanavu Illam is designed and intended strictly for adults aged 18 years and above. We do not knowingly solicit or collect personal information from individuals under the age of 18.

## 8. Security Safeguards & Breach Management
We protect your data using industry-grade measures including TLS 1.3 encryption for data in transit, strict PostgreSQL Row Level Security (RLS) ensuring that users can only access their own records, private container networking, and rate-limited API endpoints. In the unlikely event of a verified data incident, we will notify affected users and regulatory bodies within the statutory timeline.

## 9. Grievance Redressal & Contact Information
In compliance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 and the DPDP Act, 2023, the details of our Grievance Officer are:
* **Publisher / Entity:** Kanavu Illam Technologies
* **Grievance Officer:** Chandramouli S
* **Designation:** Grievance Officer
* **Address:** Kanavu Illam Technologies, Tamil Nadu, India
* **Grievance Email:** grievance@kanavuillam.com (cc: support@kanavuillam.com)
* **Statutory SLA:** Acknowledgment within 24 hours; resolution within 15–30 days.

By using Kanavu Illam, you consent to this Privacy Policy.
''';
}
