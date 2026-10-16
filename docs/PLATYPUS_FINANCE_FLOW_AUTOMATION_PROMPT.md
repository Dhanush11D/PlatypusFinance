# PLATYPUS FINANCE — SALESFORCE FLOW AUTOMATION SPECIFICATION PROMPT

> **How to Use**: Copy and paste the entire prompt below directly into **ChatGPT**. It contains all object schemas, field API names, business rules, and step-by-step logic requirements needed to guide you through creating each Salesforce Flow in Flow Builder.

---

```markdown
You are an expert Salesforce Flow Architect and Senior Financial Automation Specialist. 

I have a production-grade Loan Origination and Servicing System named "Platypus Finance" running in my Salesforce Developer Edition org. 
The custom objects, Apex services, Lightning Web Components, and demo records across all entities are already built, tested, and deployed.

However, the system currently lacks key business automations. I need you to give me exact, step-by-step instructions (trigger type, entry conditions, element configurations, formula variables, decision criteria, and record updates) to create the following Salesforce Flows in Lightning Flow Builder.

---

### SYSTEM OBJECT SCHEMA & FIELD REFERENCE:

1. **Account (Standard)**:
   - `Customer_Type__c` (Picklist: Individual, Business)
   - `Customer_Status__c` (Picklist: Active, Inactive, Blocked)
   - `KYC_Status__c` (Picklist: Pending, Verified, Rejected)
   - `Risk_Category__c` (Picklist: Low, Medium, High)

2. **Contact (Standard)**:
   - `Monthly_Income__c` (Currency)
   - `Occupation__c` (Picklist: Salaried, Self-Employed, Business Owner, Other)
   - `Employer_Name__c` (Text)

3. **Loan_Application__c (Custom Object)**:
   - `Customer_Account__c` (Lookup to Account - Required)
   - `Applicant_Contact__c` (Lookup to Contact - Required)
   - `Loan_Segment__c` (Picklist: Personal, Business, Emergency, Education)
   - `Requested_Amount__c` (Currency, 10,000 to 500,000)
   - `Requested_Tenure_Months__c` (Number, 3 to 53)
   - `Purpose_of_Loan__c` (Picklist: Medical, Education, Home Improvement, Business Expansion, Personal Expenses, Other)
   - `Application_Status__c` (Picklist: Draft, Submitted, Under Review, Approved, Rejected, Withdrawn)
   - `Approval_Stage__c` (Picklist: Not Started, Manager Review, Decision Complete)
   - `Eligibility_Status__c` (Picklist: Not Checked, Eligible, Ineligible)
   - `Monthly_Income_Snapshot__c` (Currency)
   - `Assigned_Manager__c` (Lookup to User)
   - `Approved_By__c` (Lookup to User), `Approved_Date__c` (DateTime)
   - `Rejected_By__c` (Lookup to User), `Rejected_Date__c` (DateTime), `Rejection_Reason__c` (Picklist: Insufficient Income, Eligibility Criteria Not Met, Incomplete Documentation, High Risk, Other)

4. **Loan__c (Custom Object - Active Loan Contract)**:
   - `Loan_Application__c` (Lookup to Loan_Application__c - Required)
   - `Customer_Account__c` (Lookup to Account - Required)
   - `Borrower_Contact__c` (Lookup to Contact - Required)
   - `Principal_Amount__c` (Currency)
   - `Disbursed_Amount__c` (Currency)
   - `Annual_Interest_Rate__c` (Percent)
   - `Tenure_Months__c` (Number)
   - `Monthly_Installment__c` (Currency - EMI)
   - `Loan_Start_Date__c` (Date)
   - `First_Due_Date__c` (Date)
   - `Next_Payment_Due_Date__c` (Date)
   - `Maturity_Date__c` (Date)
   - `Loan_Status__c` (Picklist: Active, Delinquent, Defaulted, Closed)
   - `Outstanding_Balance__c` (Currency)
   - `Total_Amount_Paid__c` (Currency)
   - `Overdue_Amount__c` (Currency)
   - `Disbursed_By__c` (Lookup to User)

5. **Loan_Payment__c (Custom Object - Repayment Ledger)**:
   - `Loan__c` (Lookup to Loan__c - Required)
   - `Payment_Amount__c` (Currency)
   - `Payment_Date__c` (Date)
   - `Payment_Method__c` (Picklist: Cash, UPI, Bank Transfer, Card, Cheque, Other)
   - `Payment_Type__c` (Picklist: Regular Installment, Part Payment, Full Settlement, Penalty, Other)
   - `Payment_Status__c` (Picklist: Pending, Successful, Reversed, Failed)
   - `Transaction_Reference__c` (Text)
   - `Payment_Notes__c` (Text/Long)
   - `Received_By__c` (Lookup to User)

---

### AUTOMATION FLOW PROBLEMS TO SOLVE:

Please provide the exact design for each of the following 6 Salesforce Flows. For each flow, outline:
- **Flow Type**: (Record-Triggered Flow / Scheduled-Triggered Flow)
- **Object**: Target object and Trigger timing (Before Save vs After Save)
- **Trigger Conditions**: Entry criteria and execution frequency
- **Elements & Logic**: Step-by-step element diagram (Get Records, Decision, Assignment, Update Records, Send Email / Custom Notification, Create Tasks)
- **Formulas / Variables**: Any formulas required (e.g. date calculations, text templates)

#### FLOW 1: Application Submission, Auto-Routing & Applicant Confirmation
- **Problem**: When a customer or officer submits a `Loan_Application__c` (`Application_Status__c` changes to `Submitted`):
  1. If `Assigned_Manager__c` is blank, auto-assign an underwriter based on `Loan_Segment__c`:
     - If `Loan_Segment__c = 'Business'` OR `Requested_Amount__c > 100,000` -> Assign to Senior Underwriting Queue / User.
     - Otherwise -> Assign to the Default Underwriter.
  2. Send an immediate Bell Notification to the assigned manager alerting them of the new file.
  3. Send an automated confirmation email to the Applicant Contact (`Applicant_Contact__r.Email`) containing the Application Number, Requested Amount, and a message that review is underway.

#### FLOW 2: Blocked Customer / KYC Rejection Application Cascade
- **Problem**: In compliance testing, when an `Account` is marked as `Customer_Status__c = 'Blocked'` OR `KYC_Status__c = 'Rejected'`:
  - Active pending applications (`Application_Status__c` in `Draft`, `Submitted`, or `Under Review`) remain open and continue to appear in underwriter queues, risking unlawful disbursement.
- **Requirement**: A Record-Triggered Flow on `Account` that immediately queries all pending `Loan_Application__c` child records, updates their `Application_Status__c` to `Withdrawn`, sets `Eligibility_Status__c` to `Ineligible`, sets `Rejection_Reason__c` to `High Risk`, and stamps `Decision_Comments__c` with: *"Auto-Withdrawn: Customer Account Blocked or KYC verification rejected."*

#### FLOW 3: Loan Disbursement & Borrower Welcome Notification
- **Problem**: When a loan is disbursed and a `Loan__c` record is created with `Loan_Status__c = 'Active'`:
  - The borrower contact receives no formal notification with their loan details.
- **Requirement**: A Record-Triggered Flow on `Loan__c` (After Insert):
  1. Ensure `Loan_Status__c = 'Active'`.
  2. Send a Welcome Email to `Borrower_Contact__r.Email` formatted with:
     - Loan Number (`Name`)
     - Disbursed Amount
     - Monthly Installment (EMI)
     - First Due Date & Next Due Date
     - Repayment instructions and accepted methods.

#### FLOW 4: Daily Scheduled Repayment Due & Delinquency Tracker
- **Problem**: Currently, loans remain marked `Active` even if payments are overdue, and borrowers get no upcoming due date reminders.
- **Requirement**: A Daily Schedule-Triggered Flow running every morning at 06:00 on `Loan__c`:
  1. **Upcoming Reminder (3 Days Before Due)**: If `Loan_Status__c = 'Active'` and `Next_Payment_Due_Date__c = TODAY + 3`, send an upcoming payment reminder email to the borrower.
  2. **Delinquency Escalation (Grace Period Exceeded)**: If `Loan_Status__c = 'Active'` and `Next_Payment_Due_Date__c < TODAY - 15` (15 days past due):
     - Update `Loan_Status__c` from `'Active'` to `'Delinquent'`.
     - Create a High-Priority Task assigned to `Assigned_Manager__c`: *"Immediate Action Required: Loan {Name} is 15+ days past due. Initiate collection call."*

#### FLOW 5: Payment Receipt & Loan Payoff Auto-Closure
- **Problem**: When a customer makes a payment and `Loan_Payment__c` transitions to `Payment_Status__c = 'Successful'`:
  - The borrower receives no receipt.
  - When the remaining `Outstanding_Balance__c` of the related `Loan__c` reaches `0` (or `Payment_Type__c = 'Full Settlement'`), the loan status remains `Active` instead of automatically completing.
- **Requirement**: A Record-Triggered Flow on `Loan_Payment__c` (After Update, when `Payment_Status__c` transitions to `Successful`):
  1. Send an email receipt to the borrower (`Loan__r.Borrower_Contact__r.Email`) with Transaction Reference, Amount Paid, and Remaining Balance.
  2. Check if related `Loan__r.Outstanding_Balance__c <= 0`:
     - If balance is 0, update the parent `Loan__c`: set `Loan_Status__c = 'Closed'`.
     - Create a Task for the Loan Manager: *"Issue No-Objection Certificate (NOC) and Close File for {Loan__r.Name}"*.

#### FLOW 6: Payment Failure & Bounce Alert
- **Problem**: When a `Loan_Payment__c` record is marked `Payment_Status__c = 'Failed'` or `Reversed` (e.g. bounced cheque, disputed ACH):
  - Officers have no visibility into the failed payment attempt.
- **Requirement**: A Record-Triggered Flow on `Loan_Payment__c` (After Update):
  1. Trigger when `Payment_Status__c` equals `Failed` or `Reversed`.
  2. Create a High-Priority Task assigned to the Loan Manager: *"URGENT: Repayment attempt failed/reversed for Loan {Loan__r.Name}. Transaction Ref: {Transaction_Reference__c}. Contact customer immediately."*
  3. Send an immediate email alert to the borrower informing them of the dishonored payment and requesting prompt remediation.

---

Please provide the detailed, step-by-step instructions for building each flow one by one.
```
