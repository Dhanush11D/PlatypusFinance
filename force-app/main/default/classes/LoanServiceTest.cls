@IsTest
private class LoanServiceTest {

    private static Account createCustomer() {
        Account customer = new Account(
            Name = 'Platypus Loan Test Customer',
            Customer_Type__c = 'Individual',
            Customer_Status__c = 'Active',
            KYC_Status__c = 'Verified',
            Risk_Category__c = 'Low',
            Customer_Since__c = Date.today()
        );
        insert customer;
        return customer;
    }

    private static Contact createContact(Id accountId) {
        Contact applicant = new Contact(
            FirstName = 'Loan',
            LastName = 'Applicant',
            AccountId = accountId,
            Monthly_Income__c = 50000
        );
        insert applicant;
        return applicant;
    }

    private static Loan_Application__c createApprovedApplication() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

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
        return application;
    }

    private static Loan__c createFullyRepaidLoan() {
        Loan_Application__c application =
            createApprovedApplication();

        Loan__c loan = new Loan__c(
            Loan_Application__c = application.Id,
            Customer_Account__c = application.Customer_Account__c,
            Borrower_Contact__c = application.Applicant_Contact__c,
            Assigned_Manager__c = UserInfo.getUserId(),
            Principal_Amount__c = 100000,
            Annual_Interest_Rate__c = 12,
            Tenure_Months__c = 12,
            Loan_Start_Date__c = Date.today().addMonths(-12),
            First_Due_Date__c = Date.today().addMonths(-11),
            Maturity_Date__c = Date.today(),
            Loan_Status__c = 'Active',
            Disbursement_Date__c = Date.today().addMonths(-12),
            Disbursed_Amount__c = 100000,
            Disbursed_By__c = UserInfo.getUserId(),
            Total_Amount_Paid__c = 100000,
            Monthly_Installment__c = 8884.88,
            Next_Payment_Due_Date__c = Date.today(),
            Outstanding_Balance__c = 0,
            Overdue_Amount__c = 0
        );

        insert loan;
        return loan;
    }

    @IsTest
    static void testInterestRates() {
        System.assertEquals(
            Decimal.valueOf('12.00'),
            LoanService.getAnnualInterestRate('Personal')
        );
        System.assertEquals(
            Decimal.valueOf('15.00'),
            LoanService.getAnnualInterestRate('Business')
        );
        System.assertEquals(
            Decimal.valueOf('18.00'),
            LoanService.getAnnualInterestRate('Emergency')
        );
        System.assertEquals(
            Decimal.valueOf('8.00'),
            LoanService.getAnnualInterestRate('Education')
        );
    }

    @IsTest
    static void testInvalidInterestRate() {
        Boolean thrown = false;

        try {
            LoanService.getAnnualInterestRate('Unknown');
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testMonthlyInstallment() {
        Decimal installment =
            LoanService.calculateMonthlyInstallment(
                100000, 12, 12
            );

        System.assertEquals(
            Decimal.valueOf('8884.88'),
            installment
        );
    }

    @IsTest
    static void testZeroInterestInstallment() {
        Decimal installment =
            LoanService.calculateMonthlyInstallment(
                12000, 0, 12
            );

        System.assertEquals(
            Decimal.valueOf('1000.00'),
            installment
        );
    }

    @IsTest
    static void testInvalidInstallmentInputs() {
        Boolean thrown = false;

        try {
            LoanService.calculateMonthlyInstallment(
                0, 12, 12
            );
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testDisbursementCreatesActiveLoan() {
        Loan_Application__c application =
            createApprovedApplication();

        Test.startTest();
        Id loanId = LoanService.disburseApprovedApplication(
            application.Id,
            Date.today()
        );
        Test.stopTest();

        Loan__c loan = [
            SELECT Id, Loan_Application__c,
                   Customer_Account__c, Borrower_Contact__c,
                   Assigned_Manager__c, Principal_Amount__c,
                   Annual_Interest_Rate__c, Tenure_Months__c,
                   Loan_Start_Date__c, First_Due_Date__c,
                   Maturity_Date__c, Loan_Status__c,
                   Disbursement_Date__c, Disbursed_Amount__c,
                   Disbursed_By__c, Total_Amount_Paid__c,
                   Monthly_Installment__c,
                   Next_Payment_Due_Date__c,
                   Outstanding_Balance__c, Overdue_Amount__c
            FROM Loan__c
            WHERE Id = :loanId
        ];

        System.assertEquals(application.Id, loan.Loan_Application__c);
        System.assertEquals('Active', loan.Loan_Status__c);
        System.assertEquals(Decimal.valueOf('100000'), loan.Principal_Amount__c);
        System.assertEquals(Decimal.valueOf('12.00'), loan.Annual_Interest_Rate__c);
        System.assertEquals(Date.today(), loan.Disbursement_Date__c);
        System.assertEquals(UserInfo.getUserId(), loan.Disbursed_By__c);
        System.assertEquals(Decimal.valueOf('0'), loan.Total_Amount_Paid__c);
        System.assertEquals(Decimal.valueOf('100000'), loan.Outstanding_Balance__c);
        System.assertEquals(Date.today().addMonths(1), loan.First_Due_Date__c);
        System.assertEquals(Date.today().addMonths(12), loan.Maturity_Date__c);
        System.assertNotEquals(null, loan.Next_Payment_Due_Date__c);
    }

    @IsTest
    static void testDuplicateDisbursementBlocked() {
        Loan_Application__c application =
            createApprovedApplication();

        LoanService.disburseApprovedApplication(
            application.Id, Date.today()
        );

        Boolean thrown = false;

        try {
            LoanService.disburseApprovedApplication(
                application.Id, Date.today()
            );
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Loan__c
             WHERE Loan_Application__c = :application.Id]
        );
    }

    @IsTest
    static void testUnapprovedApplicationBlocked() {
        Loan_Application__c application =
            createApprovedApplication();

        application.Application_Status__c = 'Under Review';
        update application;

        Boolean thrown = false;

        try {
            LoanService.disburseApprovedApplication(
                application.Id, Date.today()
            );
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testFutureDisbursementDateBlocked() {
        Loan_Application__c application =
            createApprovedApplication();

        Boolean thrown = false;

        try {
            LoanService.disburseApprovedApplication(
                application.Id, Date.today().addDays(1)
            );
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testMissingEligibilityBlocked() {
        Loan_Application__c application =
            createApprovedApplication();

        application.Eligibility_Status__c = 'Manual Review';
        update application;

        Boolean thrown = false;

        try {
            LoanService.disburseApprovedApplication(
                application.Id, Date.today()
            );
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testGetLoanAndCustomerLoans() {
        Loan_Application__c application =
            createApprovedApplication();

        Id loanId = LoanService.disburseApprovedApplication(
            application.Id, Date.today()
        );

        System.assertEquals(
            loanId,
            LoanService.getLoan(loanId).Id
        );

        List<Loan__c> customerLoans =
            LoanService.getCustomerLoans(
                application.Customer_Account__c
            );

        System.assertEquals(1, customerLoans.size());
        System.assertEquals(loanId, customerLoans[0].Id);

        System.assertEquals(
            1,
            LoanService.getMyAssignedLoans().size()
        );
    }

    @IsTest
    static void testCannotCloseLoanWithOutstandingBalance() {
        Loan_Application__c application =
            createApprovedApplication();

        Id loanId = LoanService.disburseApprovedApplication(
            application.Id, Date.today()
        );

        Boolean thrown = false;

        try {
            LoanService.closeLoan(loanId);
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testCloseFullyRepaidLoan() {
        Loan__c loan = createFullyRepaidLoan();
        Date originalDueDate = loan.Next_Payment_Due_Date__c;

        Test.startTest();
        LoanService.closeLoan(loan.Id);
        Test.stopTest();

        Loan__c closedLoan = [
            SELECT Loan_Status__c,
                   Next_Payment_Due_Date__c,
                   Outstanding_Balance__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals('Closed', closedLoan.Loan_Status__c);
        System.assertEquals(Decimal.valueOf('0'), closedLoan.Outstanding_Balance__c);
        System.assertEquals(
            originalDueDate,
            closedLoan.Next_Payment_Due_Date__c
        );
    }

    @IsTest
    static void testCancelUndisbursedLoanBlockedForActiveLoan() {
        Loan_Application__c application =
            createApprovedApplication();

        Id loanId = LoanService.disburseApprovedApplication(
            application.Id, Date.today()
        );

        Boolean thrown = false;

        try {
            LoanService.cancelUndisbursedLoan(loanId);
        } catch (LoanService.InvalidLoanException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }
}