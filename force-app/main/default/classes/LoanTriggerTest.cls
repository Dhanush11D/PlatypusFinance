@IsTest
private class LoanTriggerTest {

    private static Loan__c createActiveLoan() {
        Account customer = new Account(
            Name = 'Loan Trigger Test Customer',
            Customer_Type__c = 'Individual',
            Customer_Status__c = 'Active',
            KYC_Status__c = 'Verified',
            Risk_Category__c = 'Low',
            Customer_Since__c = Date.today()
        );
        insert customer;

        Contact applicant = new Contact(
            FirstName = 'Loan',
            LastName = 'Trigger Applicant',
            AccountId = customer.Id,
            Monthly_Income__c = 50000
        );
        insert applicant;

        Loan_Application__c application =
            new Loan_Application__c(
                Customer_Account__c = customer.Id,
                Applicant_Contact__c = applicant.Id,
                Application_Date__c = Date.today(),
                Loan_Segment__c = 'Personal',
                Requested_Amount__c = 100000,
                Requested_Tenure_Months__c = 12,
                Purpose_of_Loan__c = 'Personal Expenses',
                Application_Status__c = 'Approved',
                Approval_Stage__c = 'Decision Complete',
                Eligibility_Status__c = 'Eligible',
                Assigned_Manager__c = UserInfo.getUserId(),
                Approved_By__c = UserInfo.getUserId(),
                Approved_Date__c = System.now()
            );
        insert application;

        Id loanId = LoanService.disburseApprovedApplication(
            application.Id,
            Date.today()
        );

        return [
            SELECT Id,
                   Loan_Status__c,
                   Principal_Amount__c,
                   Annual_Interest_Rate__c,
                   Tenure_Months__c,
                   Loan_Start_Date__c,
                   First_Due_Date__c,
                   Maturity_Date__c,
                   Disbursement_Date__c,
                   Disbursed_Amount__c,
                   Disbursed_By__c,
                   Total_Amount_Paid__c,
                   Outstanding_Balance__c,
                   Overdue_Amount__c,
                   Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Id = :loanId
        ];
    }

    @IsTest
    static void testServiceCreatesValidActiveLoan() {
        Loan__c loan = createActiveLoan();

        System.assertEquals('Active', loan.Loan_Status__c);
        System.assertNotEquals(null, loan.Disbursement_Date__c);
        System.assertNotEquals(null, loan.Disbursed_By__c);
        System.assertNotEquals(null, loan.Loan_Start_Date__c);
        System.assert(
            loan.Disbursed_Amount__c > 0
        );
    }

    @IsTest
    static void testRejectPrincipalBelowMinimum() {
        Loan__c loan = createActiveLoan();
        loan.Principal_Amount__c = 9999;

        Test.startTest();
        Database.SaveResult result = Database.update(loan, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains(
                'between ₹10,000 and ₹5,00,000'
            )
        );
    }

    @IsTest
    static void testRejectPrincipalAboveMaximum() {
        Loan__c loan = createActiveLoan();
        loan.Principal_Amount__c = 500001;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectInvalidTenure() {
        Loan__c loan = createActiveLoan();
        loan.Tenure_Months__c = 54;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectNegativeInterestRate() {
        Loan__c loan = createActiveLoan();
        loan.Annual_Interest_Rate__c = -1;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectInterestRateAboveMaximum() {
        Loan__c loan = createActiveLoan();
        loan.Annual_Interest_Rate__c = 101;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectNegativeOutstandingBalance() {
        Loan__c loan = createActiveLoan();
        loan.Outstanding_Balance__c = -1;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectNegativeTotalPaid() {
        Loan__c loan = createActiveLoan();
        loan.Total_Amount_Paid__c = -1;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectMaturityBeforeStart() {
        Loan__c loan = createActiveLoan();
        loan.Maturity_Date__c =
            loan.Loan_Start_Date__c.addDays(-1);

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectFirstDueDateBeforeStart() {
        Loan__c loan = createActiveLoan();
        loan.First_Due_Date__c =
            loan.Loan_Start_Date__c.addDays(-1);

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectClosingLoanWithOutstandingBalance() {
        Loan__c loan = createActiveLoan();
        loan.Loan_Status__c = 'Closed';
        loan.Outstanding_Balance__c = 1000;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains(
                'outstanding balance remains'
            )
        );
    }

    @IsTest
    static void testRejectClearingDisbursementDate() {
        Loan__c loan = createActiveLoan();
        loan.Disbursement_Date__c = null;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectClearingDisbursedBy() {
        Loan__c loan = createActiveLoan();
        loan.Disbursed_By__c = null;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testInvalidUpdateDoesNotChangeSavedLoan() {
        Loan__c loan = createActiveLoan();
        Decimal originalPrincipal = loan.Principal_Amount__c;

        loan.Principal_Amount__c = 5000;

        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess());

        Loan__c savedLoan = [
            SELECT Principal_Amount__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals(
            originalPrincipal,
            savedLoan.Principal_Amount__c
        );
    }

    @IsTest
    static void testRejectNegativeFinancialFields() {
        Loan__c loan = createActiveLoan();
        loan.Overdue_Amount__c = -100;
        System.assertEquals(false, Database.update(loan, false).isSuccess());

        loan = [SELECT Id, Overdue_Amount__c, Disbursed_Amount__c, Loan_Start_Date__c FROM Loan__c WHERE Id = :loan.Id];
        loan.Disbursed_Amount__c = -500;
        System.assertEquals(false, Database.update(loan, false).isSuccess());

        loan = [SELECT Id, Overdue_Amount__c, Disbursed_Amount__c, Loan_Start_Date__c FROM Loan__c WHERE Id = :loan.Id];
        loan.Disbursed_Amount__c = 0;
        System.assertEquals(false, Database.update(loan, false).isSuccess());

        loan = [SELECT Id, Overdue_Amount__c, Disbursed_Amount__c, Loan_Start_Date__c FROM Loan__c WHERE Id = :loan.Id];
        loan.Loan_Start_Date__c = null;
        System.assertEquals(false, Database.update(loan, false).isSuccess());
    }
}