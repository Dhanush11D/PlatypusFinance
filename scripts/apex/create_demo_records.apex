// Clean up existing demo data if any from prior partial attempts
List<Loan_Payment__c> oldPayments = [SELECT Id FROM Loan_Payment__c WHERE Loan__r.Customer_Account__r.Name IN ('Apex Tech Solutions Inc.', 'Elena Rostova', 'Marcus Vance', 'Nexus Logistics LLC', 'Jordan Hayes', 'Horizon Retailers')];
delete oldPayments;

List<Loan__c> oldLoans = [SELECT Id FROM Loan__c WHERE Customer_Account__r.Name IN ('Apex Tech Solutions Inc.', 'Elena Rostova', 'Marcus Vance', 'Nexus Logistics LLC', 'Jordan Hayes', 'Horizon Retailers')];
delete oldLoans;

List<Loan_Application__c> oldApps = [SELECT Id FROM Loan_Application__c WHERE Customer_Account__r.Name IN ('Apex Tech Solutions Inc.', 'Elena Rostova', 'Marcus Vance', 'Nexus Logistics LLC', 'Jordan Hayes', 'Horizon Retailers')];
delete oldApps;

List<Contact> oldContacts = [SELECT Id FROM Contact WHERE Account.Name IN ('Apex Tech Solutions Inc.', 'Elena Rostova', 'Marcus Vance', 'Nexus Logistics LLC', 'Jordan Hayes', 'Horizon Retailers')];
delete oldContacts;

List<Account> oldAccounts = [SELECT Id FROM Account WHERE Name IN ('Apex Tech Solutions Inc.', 'Elena Rostova', 'Marcus Vance', 'Nexus Logistics LLC', 'Jordan Hayes', 'Horizon Retailers')];
delete oldAccounts;

Id currentUserId = UserInfo.getUserId();

// 1. ACCOUNTS (6 distinct customer profiles)
List<Account> accountsToInsert = new List<Account>{
    new Account(
        Name = 'Apex Tech Solutions Inc.',
        Customer_Type__c = 'Business',
        Customer_Status__c = 'Active',
        KYC_Status__c = 'Verified',
        Risk_Category__c = 'Low',
        Customer_Since__c = Date.today().addYears(-2)
    ),
    new Account(
        Name = 'Elena Rostova',
        Customer_Type__c = 'Individual',
        Customer_Status__c = 'Active',
        KYC_Status__c = 'Verified',
        Risk_Category__c = 'Low',
        Customer_Since__c = Date.today().addMonths(-8)
    ),
    new Account(
        Name = 'Marcus Vance',
        Customer_Type__c = 'Individual',
        Customer_Status__c = 'Active',
        KYC_Status__c = 'Verified',
        Risk_Category__c = 'Medium',
        Customer_Since__c = Date.today().addMonths(-3)
    ),
    new Account(
        Name = 'Nexus Logistics LLC',
        Customer_Type__c = 'Business',
        Customer_Status__c = 'Active',
        KYC_Status__c = 'Verified',
        Risk_Category__c = 'Low',
        Customer_Since__c = Date.today().addYears(-1)
    ),
    new Account(
        Name = 'Horizon Retailers',
        Customer_Type__c = 'Business',
        Customer_Status__c = 'Active',
        KYC_Status__c = 'Verified',
        Risk_Category__c = 'Medium',
        Customer_Since__c = Date.today().addMonths(-6)
    ),
    new Account(
        Name = 'Jordan Hayes',
        Customer_Type__c = 'Individual',
        Customer_Status__c = 'Blocked',
        KYC_Status__c = 'Rejected',
        Risk_Category__c = 'High',
        Customer_Since__c = Date.today().addMonths(-1)
    )
};
insert accountsToInsert;

// 2. CONTACTS
List<Contact> contactsToInsert = new List<Contact>{
    new Contact(
        FirstName = 'Sarah',
        LastName = 'Jenkins',
        AccountId = accountsToInsert[0].Id,
        Email = 'sjenkins@apextechdemo.com',
        Phone = '555-0101',
        Monthly_Income__c = 18000,
        Occupation__c = 'Business Owner',
        Employer_Name__c = 'Apex Tech Solutions Inc.'
    ),
    new Contact(
        FirstName = 'Elena',
        LastName = 'Rostova',
        AccountId = accountsToInsert[1].Id,
        Email = 'erostova@example.com',
        Phone = '555-0102',
        Monthly_Income__c = 12500,
        Occupation__c = 'Salaried',
        Employer_Name__c = 'Google Cloud'
    ),
    new Contact(
        FirstName = 'Marcus',
        LastName = 'Vance',
        AccountId = accountsToInsert[2].Id,
        Email = 'mvance@example.com',
        Phone = '555-0103',
        Monthly_Income__c = 7000,
        Occupation__c = 'Salaried',
        Employer_Name__c = 'Deloitte'
    ),
    new Contact(
        FirstName = 'David',
        LastName = 'Kim',
        AccountId = accountsToInsert[3].Id,
        Email = 'dkim@nexuslogdemo.com',
        Phone = '555-0104',
        Monthly_Income__c = 22000,
        Occupation__c = 'Business Owner',
        Employer_Name__c = 'Nexus Logistics LLC'
    ),
    new Contact(
        FirstName = 'Alex',
        LastName = 'Chen',
        AccountId = accountsToInsert[4].Id,
        Email = 'achen@horizonretaildemo.com',
        Phone = '555-0105',
        Monthly_Income__c = 16000,
        Occupation__c = 'Business Owner',
        Employer_Name__c = 'Horizon Retailers'
    ),
    new Contact(
        FirstName = 'Jordan',
        LastName = 'Hayes',
        AccountId = accountsToInsert[5].Id,
        Email = 'jhayes@example.com',
        Phone = '555-0106',
        Monthly_Income__c = 3000,
        Occupation__c = 'Self-Employed',
        Employer_Name__c = 'Freelance'
    )
};
insert contactsToInsert;

// 3. LOAN APPLICATIONS
List<Loan_Application__c> appsToInsert = new List<Loan_Application__c>{
    // App 0: Apex Tech - Approved (Linked to Loan 1)
    new Loan_Application__c(
        Customer_Account__c = accountsToInsert[0].Id,
        Applicant_Contact__c = contactsToInsert[0].Id,
        Loan_Segment__c = 'Business',
        Requested_Amount__c = 120000,
        Requested_Tenure_Months__c = 36,
        Purpose_of_Loan__c = 'Business Expansion',
        Application_Date__c = Date.today().addMonths(-2),
        Application_Status__c = 'Approved',
        Approval_Stage__c = 'Decision Complete',
        Eligibility_Status__c = 'Eligible',
        Monthly_Income_Snapshot__c = 18000,
        Assigned_Manager__c = currentUserId,
        Approved_By__c = currentUserId,
        Approved_Date__c = DateTime.now().addMonths(-2),
        Decision_Comments__c = 'Strong commercial balance sheet and proven cash flow.'
    ),
    // App 1: Elena Rostova - Approved (Awaiting disbursement in the Loan Officer UI!)
    new Loan_Application__c(
        Customer_Account__c = accountsToInsert[1].Id,
        Applicant_Contact__c = contactsToInsert[1].Id,
        Loan_Segment__c = 'Personal',
        Requested_Amount__c = 50000,
        Requested_Tenure_Months__c = 24,
        Purpose_of_Loan__c = 'Personal Expenses',
        Application_Date__c = Date.today().addDays(-4),
        Application_Status__c = 'Approved',
        Approval_Stage__c = 'Decision Complete',
        Eligibility_Status__c = 'Eligible',
        Monthly_Income_Snapshot__c = 12500,
        Assigned_Manager__c = currentUserId,
        Approved_By__c = currentUserId,
        Approved_Date__c = DateTime.now().addDays(-1),
        Decision_Comments__c = 'Approved with standard personal rate. Low DTI and high score.'
    ),
    // App 2: Marcus Vance - Submitted / Pending Review
    new Loan_Application__c(
        Customer_Account__c = accountsToInsert[2].Id,
        Applicant_Contact__c = contactsToInsert[2].Id,
        Loan_Segment__c = 'Personal',
        Requested_Amount__c = 35000,
        Requested_Tenure_Months__c = 24,
        Purpose_of_Loan__c = 'Home Improvement',
        Application_Date__c = Date.today(),
        Application_Status__c = 'Submitted',
        Approval_Stage__c = 'Manager Review',
        Eligibility_Status__c = 'Eligible',
        Monthly_Income_Snapshot__c = 7000,
        Assigned_Manager__c = currentUserId
    ),
    // App 3: Nexus Logistics - Under Review
    new Loan_Application__c(
        Customer_Account__c = accountsToInsert[3].Id,
        Applicant_Contact__c = contactsToInsert[3].Id,
        Loan_Segment__c = 'Business',
        Requested_Amount__c = 150000,
        Requested_Tenure_Months__c = 36,
        Purpose_of_Loan__c = 'Business Expansion',
        Application_Date__c = Date.today().addDays(-2),
        Application_Status__c = 'Under Review',
        Approval_Stage__c = 'Manager Review',
        Eligibility_Status__c = 'Eligible',
        Monthly_Income_Snapshot__c = 22000,
        Assigned_Manager__c = currentUserId
    ),
    // App 4: Horizon Retailers - Approved (Linked to Loan 2)
    new Loan_Application__c(
        Customer_Account__c = accountsToInsert[4].Id,
        Applicant_Contact__c = contactsToInsert[4].Id,
        Loan_Segment__c = 'Business',
        Requested_Amount__c = 40000,
        Requested_Tenure_Months__c = 24,
        Purpose_of_Loan__c = 'Business Expansion',
        Application_Date__c = Date.today().addMonths(-4),
        Application_Status__c = 'Approved',
        Approval_Stage__c = 'Decision Complete',
        Eligibility_Status__c = 'Eligible',
        Monthly_Income_Snapshot__c = 16000,
        Assigned_Manager__c = currentUserId,
        Approved_By__c = currentUserId,
        Approved_Date__c = DateTime.now().addMonths(-4),
        Decision_Comments__c = 'Seasonal inventory expansion loan.'
    ),
    // App 5: Jordan Hayes - Rejected
    new Loan_Application__c(
        Customer_Account__c = accountsToInsert[5].Id,
        Applicant_Contact__c = contactsToInsert[5].Id,
        Loan_Segment__c = 'Personal',
        Requested_Amount__c = 45000,
        Requested_Tenure_Months__c = 12,
        Purpose_of_Loan__c = 'Other',
        Application_Date__c = Date.today().addDays(-10),
        Application_Status__c = 'Rejected',
        Approval_Stage__c = 'Decision Complete',
        Eligibility_Status__c = 'Ineligible',
        Monthly_Income_Snapshot__c = 3000,
        Rejected_By__c = currentUserId,
        Rejected_Date__c = DateTime.now().addDays(-8),
        Rejection_Reason__c = 'High Risk',
        Decision_Comments__c = 'Customer status is Blocked and KYC verification was rejected.'
    )
};
insert appsToInsert;

// 4. ACTIVE LOANS
// Loan 1 for Apex Tech Solutions
Loan__c loan1 = new Loan__c(
    Loan_Application__c = appsToInsert[0].Id,
    Customer_Account__c = accountsToInsert[0].Id,
    Borrower_Contact__c = contactsToInsert[0].Id,
    Principal_Amount__c = 120000,
    Disbursed_Amount__c = 120000,
    Annual_Interest_Rate__c = 15.00,
    Tenure_Months__c = 36,
    Monthly_Installment__c = 4159.84,
    Loan_Start_Date__c = Date.today().addMonths(-2),
    Disbursement_Date__c = Date.today().addMonths(-2),
    First_Due_Date__c = Date.today().addMonths(-1),
    Next_Payment_Due_Date__c = Date.today().addMonths(1),
    Maturity_Date__c = Date.today().addMonths(34),
    Loan_Status__c = 'Active',
    Outstanding_Balance__c = 120000.00,
    Total_Amount_Paid__c = 0.00,
    Disbursed_By__c = currentUserId,
    Assigned_Manager__c = currentUserId
);

// Loan 2 for Horizon Retailers (Overdue / Delinquent Demo)
Loan__c loan2 = new Loan__c(
    Loan_Application__c = appsToInsert[4].Id,
    Customer_Account__c = accountsToInsert[4].Id,
    Borrower_Contact__c = contactsToInsert[4].Id,
    Principal_Amount__c = 40000,
    Disbursed_Amount__c = 40000,
    Annual_Interest_Rate__c = 15.00,
    Tenure_Months__c = 24,
    Monthly_Installment__c = 1939.00,
    Loan_Start_Date__c = Date.today().addMonths(-4),
    Disbursement_Date__c = Date.today().addMonths(-4),
    First_Due_Date__c = Date.today().addMonths(-3),
    Next_Payment_Due_Date__c = Date.today().addDays(-15),
    Maturity_Date__c = Date.today().addMonths(20),
    Loan_Status__c = 'Active',
    Outstanding_Balance__c = 40000.00,
    Total_Amount_Paid__c = 0.00,
    Overdue_Amount__c = 3878.00,
    Disbursed_By__c = currentUserId,
    Assigned_Manager__c = currentUserId
);
insert new List<Loan__c>{ loan1, loan2 };

// 5. LOAN PAYMENTS
Id p1Id = LoanPaymentService.recordPayment(
    loan1.Id,
    4159.84,
    Date.today().addMonths(-1),
    'Bank Transfer',
    'Regular Installment',
    'TXN-ACH-892101',
    'First monthly installment received on schedule.'
);
LoanPaymentService.markPaymentSuccessful(p1Id);

Id p2Id = LoanPaymentService.recordPayment(
    loan1.Id,
    4159.84,
    Date.today(),
    'Bank Transfer',
    'Regular Installment',
    'TXN-WIRE-992314',
    'Second monthly installment received via wire.'
);
LoanPaymentService.markPaymentSuccessful(p2Id);

// Record one Pending payment for Loan 2 to show in servicing pipeline
LoanPaymentService.recordPayment(
    loan2.Id,
    1939.00,
    Date.today(),
    'Bank Transfer',
    'Regular Installment',
    'TXN-PENDING-55102',
    'Payment submitted by customer via portal; awaiting clearing.'
);

System.debug('DEMO_DATA_CREATED_SUCCESSFULLY: Created complete portfolio covering Accounts, Contacts, Applications, Active Loans, Overdue Loan, and Payments.');
