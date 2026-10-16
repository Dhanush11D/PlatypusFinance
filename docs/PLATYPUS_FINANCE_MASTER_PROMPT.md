# PLATYPUS FINANCE — MASTER CONTEXT & HANDOFF PROMPT

> **Role & Persona**: Act as an elite **Senior Salesforce Technical Architect, Lead Apex Engineer, Principal Lightning Web Components (LWC) Developer, and Financial Systems Architect**.
> **Project Context**: You are taking over the **Platypus Finance** Loan Origination System (LOS) and Loan Servicing platform built on the Salesforce Lightning Platform. All baseline modules, financial calculations, triggers, UI suites, security policies, and tests have been built, verified, deployed to the Salesforce Developer Org, and synchronized with GitHub.
> **GitHub Repository**: [https://github.com/Dhanush11D/PlatypusFinance](https://github.com/Dhanush11D/PlatypusFinance)  
> **Connected Org**: `PlatypusFinanceDev` (`bollinenidhanushofficial.1a9dc5ee0bf8@agentforce.com`, Org ID: `00DgK00000cUvJ7UAK`)

---

## 1. EXECUTIVE SYSTEM SUMMARY

Platypus Finance is a production-grade Loan Origination and Servicing solution that automates the lending lifecycle from borrower intake to final loan settlement.

### Core Verified Metrics:
- **Apex Test Suite**: **103 / 103 Passed (100% Pass Rate)**
- **Org-Wide Apex Code Coverage**: **91%** (Exceeds Salesforce 75% standard)
- **Deployment Status**: Fully deployed to Org across all Metadata components (Apex, Triggers, Flows, LWCs, FlexiPages, Custom Tabs, Apps, Profiles, Permission Sets).
- **Git Synchronization**: Tracked on branch `main`.

---

## 2. INVENTORY OF COMPLETED & DEPLOYED CAPABILITIES

### A. Data Model & Architecture
1. **`Loan_Application__c` (Loan Application)**:
   - Captures Loan Amount, Loan Term (Months), Annual Interest Rate, Purpose, Employment, Monthly Income, Existing Debt, Credit Score, DTI, Risk Tier, Status, Sanction Date, Approval Conditions, Rejection Reason.
2. **`Loan__c` (Active Loan Contract)**:
   - Master active loan record generated upon disbursement. Stores Sanctioned Amount, Disbursed Amount, Outstanding Principal, Interest Rate, Monthly EMI, Payment Frequency, Start Date, End Date, Status (`Active`, `Delinquent`, `Defaulted`, `Paid Off`).
3. **`Loan_Payment__c` (Payment & Servicing Ledger)**:
   - Financial ledger recording every repayment transaction, transaction timestamp, payment method (ACH, Wire, Cash, Cheque), reference number, cashier identity, and financial allocation breakdown (Principal, Interest, Late Fees).

---

### B. Business Logic & Enterprise Apex Services
1. **`LoanApplicationService.cls`**:
   - `calculateEMI(principal, annualRate, termMonths)`: High-precision formula:
     $$\text{EMI} = \frac{P \cdot r \cdot (1 + r)^n}{(1 + r)^n - 1}$$
   - `calculateDTI(monthlyDebt, monthlyIncome)`: Evaluates borrower Debt-to-Income ratio.
   - `evaluateRiskTier(creditScore, dti)`: Classifies into `Tier 1 (Low Risk)`, `Tier 2 (Moderate Risk)`, `Tier 3 (Elevated Risk)`, `Tier 4 (High Risk / Reject)`.
   - `validateApplication(app)`: Pre-submission underwriting sanity checks.
   - `approveApplication(appId, conditions)` & `rejectApplication(appId, reason)`.

2. **`LoanService.cls`**:
   - `disburseLoan(applicationId, disbursementAmount, firstPaymentDate)`: Validates approved status, prevents double-disbursement, ensures amounts match sanction limits, creates the active `Loan__c` contract, and links records.
   - `calculatePayoffQuote(loanId)`: Returns outstanding principal, accrued interest, and settlement total.
   - `updateLoanStatus(loanId)`: Auto-progresses loan state upon maturity or full repayment.

3. **`LoanPaymentService.cls`**:
   - `processPayment(loanId, paymentAmount, paymentType, reference)`: Executes four-stage financial waterfall:
     1. Late Penalty Fees
     2. Overdue Interest
     3. Regular Monthly Interest
     4. Principal Balance
   - Safeguards against overpayments and updates remaining principal.

4. **`PFLoanOfficerDashboardController.cls`**:
   - `@AuraEnabled(cacheable=true) getDashboardMetrics()`: Live KPI aggregation (Applications Pending Review, Active Portfolio Volume, Disbursed this Month, Portfolio at Risk).
   - `@AuraEnabled(cacheable=true) getRecentApplications(recordLimit)`: Optimized query feed for queue management.

5. **Trigger Framework & Handlers**:
   - `LoanApplicationTrigger.trigger` & `LoanApplicationTriggerHandler.cls`: Prevents modification of disbursed/rejected records, automatically updates DTI on income/debt changes, and publishes notifications.
   - `LoanPaymentTrigger.trigger`: Enforces immutability on completed payment transactions and rolls up payments.

---

### C. Lightning Web Components (LWC) Suite
All components have `<target>lightning__Tab</target>`, `<target>lightning__AppPage</target>`, and `<target>lightning__RecordPage</target>` configured:
1. **`pfLoanOfficerDashboard`**:
   - Real-time KPI summaries, volume meters, interactive applications table with status badges and quick review action triggers.
2. **`pfLoanApplicationForm`**:
   - Dynamic borrower intake with customer deduplication, interactive loan amount/tenure sliders, live EMI & DTI calculation, and instant submission.
3. **`pfLoanApplicationReview`**:
   - Underwriting console displaying credit risk score gauge, financial ratios, income verification checklist, condition notes, and modal approval/rejection dialogs.
4. **`pfLoanDisbursement`**:
   - Disbursement safety desk displaying bank routing details, sanction limit validation, first repayment date selection, and active loan activation.
5. **`pfLoanRepayment`**:
   - Cashier collection terminal displaying active loan balance, principal vs interest breakdown, payment method selector, reference logging, and immediate receipt generation.

---

### D. User Experience, Navigation & Tabs
1. **Lightning App**: `Platypus_Finance.app-meta.xml` configured with standard header color `#FD7303` and organized navigation tabs.
2. **Custom Lightning App Pages (FlexiPages)**:
   - `Platypus_Finance_Dashboard`
   - `PF_New_Application`
   - `PF_Application_Review`
   - `PF_Loan_Disbursement`
   - `PF_Loan_Servicing`
3. **Custom Tabs & Profile Visibility**:
   - Tabs configured with intuitive labels:
     - `Platypus Finance Dashboard` (`Platypus_Finance_Dashboard`)
     - `New Loan Application` (`PF_New_Application`)
     - `Loan Application Review` (`PF_Application_Review`)
     - `Loan Disbursement` (`PF_Loan_Disbursement`)
     - `Loan Servicing` (`PF_Loan_Servicing`)
   - `Admin.profile-meta.xml` deployed with all tabs set to `<visibility>DefaultOn</visibility>`.
   - `Platypus_Loan_Officer_Permissions` and `Platypus_Loan_Servicing_Officer_Permissions` assigned to user.

---

## 3. COMPREHENSIVE LIST OF PENDING WORK & FUTURE ROADMAP

While the core platform is fully operational, tested, and deployed, the following enterprise enhancements represent the next logical phases of development:

### Phase 2: Automation & Accounting Batch Jobs
- [ ] **Daily Midnight Accrual Batch (`LoanDailyAccrualBatch.cls`)**:
  - Scheduled batch class to run at 00:00 daily to calculate daily interest accrual on active loans ($Principal \times \frac{Rate}{365}$).
  - Automatically evaluate grace periods and flag loans reaching 30, 60, or 90 days past due as `Delinquent` or `Defaulted`.
- [ ] **Late Fee Assessment Scheduler (`LoanLateFeeBatch.cls`)**:
  - Automatically append penalty fee records to loans with overdue installments beyond the contractual grace period.
- [ ] **Loan Amortization Schedule Object (`Loan_Schedule__c`)**:
  - Implement a granular schedule child object storing every individual monthly installment line item (Installment Number, Due Date, Principal Due, Interest Due, Status).

### Phase 3: External Integrations & Fintech APIs
- [ ] **Live Credit Bureau Integration (`CreditBureauIntegrationService.cls`)**:
  - Connect via Named Credentials and REST callout to credit reporting bureaus (Experian / Equifax / TransUnion) to retrieve verified FICO scores and credit history instead of manual entry.
- [ ] **Bank Account Verification (Plaid / Open Banking API)**:
  - Automate bank account verification, routing number validation, and instant balance checks for disbursement.
- [ ] **Payment Gateway / Automated Clearing House (ACH / Stripe)**:
  - Integrate Stripe/ACH webhook listeners to capture automated electronic borrower debits and auto-generate `Loan_Payment__c` records.

### Phase 4: Document Generation & E-Signature
- [ ] **Loan Sanction Letter & Agreement PDF Generation**:
  - Build a Visualforce or OmniStudio document template to generate downloadable, branded PDF sanction agreements.
- [ ] **DocuSign / Salesforce E-Signature Integration**:
  - Route loan agreements to borrowers for electronic signature prior to enabling the disbursement button.

### Phase 5: Customer Portal & Omni-Channel Lending
- [ ] **Experience Cloud Borrower Portal**:
  - Digital self-service portal for customers to submit loan requests, upload KYC documents (W-2s, Tax returns), inspect loan statements, and initiate repayments.
- [ ] **Agentforce / Einstein AI Underwriting Assistant**:
  - Implement Agentforce Copilot actions allowing underwriters to type: *"Summarize risk factors and repayment probability for Application APP-00042"*.

### Phase 6: Enterprise Reporting & Analytics
- [ ] **Delinquency Aging Reports (30 / 60 / 90+ Days)**:
  - Standard Salesforce matrix reports tracking Portfolio at Risk (PAR) cohorts.
- [ ] **Vintage & Loss Forecasting Dashboards**:
  - Performance analytics tracking loan repayment vintage curves by disbursement quarter.

---

## 4. INSTRUCTIONS TO PROCEED

To continue development:
1. Pull the latest commits: `git pull origin main`
2. Connect to the org: `sf org open --target-org PlatypusFinanceDev`
3. Execute any new feature against the existing service layers and run local test validation: `sf apex run test -l RunLocalTests`
