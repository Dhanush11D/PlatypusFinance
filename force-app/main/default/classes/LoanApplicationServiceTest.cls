@IsTest
private class LoanApplicationServiceTest {

    private static Account createCustomer() {
        Account customer = new Account(
            Name = 'Platypus Test Customer',
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
            FirstName = 'Test',
            LastName = 'Applicant',
            AccountId = accountId,
            Monthly_Income__c = 30000
        );
        insert applicant;
        return applicant;
    }

    private static Loan_Application__c createApplication(
        Id accountId,
        Id contactId,
        Decimal amount,
        Decimal tenure,
        String segment,
        String status
    ) {
        Loan_Application__c application =
            new Loan_Application__c(
                Customer_Account__c = accountId,
                Applicant_Contact__c = contactId,
                Application_Date__c = Date.today(),
                Loan_Segment__c = segment,
                Requested_Amount__c = amount,
                Requested_Tenure_Months__c = tenure,
                Purpose_of_Loan__c = 'Personal Expenses',
                Eligibility_Status__c = 'Not Checked',
                Application_Status__c = status,
                Approval_Stage__c = 'Manager Review',
                Assigned_Manager__c = UserInfo.getUserId()
            );

        insert application;
        return application;
    }

    private static void assertServiceException(
        Id applicationId
    ) {
        Boolean thrown = false;

        try {
            LoanApplicationService.validateApplication(applicationId);
        } catch (
            LoanApplicationService.InvalidApplicationException ex
        ) {
            thrown = true;
        }

        System.assert(thrown, 'Expected application validation to fail.');
    }

    @IsTest
    static void testInterestRates() {
        System.assertEquals(
            Decimal.valueOf('12.00'),
            LoanApplicationService.getAnnualInterestRate('Personal')
        );
        System.assertEquals(
            Decimal.valueOf('15.00'),
            LoanApplicationService.getAnnualInterestRate('Business')
        );
        System.assertEquals(
            Decimal.valueOf('18.00'),
            LoanApplicationService.getAnnualInterestRate('Emergency')
        );
        System.assertEquals(
            Decimal.valueOf('8.00'),
            LoanApplicationService.getAnnualInterestRate('Education')
        );
    }

    @IsTest
    static void testInvalidLoanSegments() {
        for (String segment :
            new List<String>{'Unknown', ''}) {

            Boolean thrown = false;

            try {
                LoanApplicationService.getAnnualInterestRate(segment);
            } catch (
                LoanApplicationService.InvalidLoanSegmentException ex
            ) {
                thrown = true;
            }

            System.assert(thrown);
        }
    }

    @IsTest
    static void testValidApplication() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 10000, 3,
            'Personal', 'Under Review'
        );

        LoanApplicationService.validateApplication(application.Id);

        System.assertEquals(
            application.Id,
            LoanApplicationService.getApplication(application.Id).Id
        );
    }

    @IsTest
    static void testAmountBelowMinimum() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 9999, 3,
            'Personal', 'Under Review'
        );

        assertServiceException(application.Id);
    }

    @IsTest
    static void testAmountAboveMaximum() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 500001, 3,
            'Personal', 'Under Review'
        );

        assertServiceException(application.Id);
    }

    @IsTest
    static void testTenureOutsideLimits() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        for (Decimal tenure : new List<Decimal>{2, 54}) {
            Loan_Application__c application = createApplication(
                customer.Id, applicant.Id, 10000, tenure,
                'Personal', 'Under Review'
            );

            assertServiceException(application.Id);
        }
    }

    @IsTest
    static void testMismatchedContactAndAccount() {
        Account firstCustomer = createCustomer();
        Account secondCustomer = createCustomer();
        Contact applicant = createContact(firstCustomer.Id);

        Loan_Application__c application = createApplication(
            secondCustomer.Id, applicant.Id, 10000, 3,
            'Personal', 'Under Review'
        );

        assertServiceException(application.Id);
    }

    @IsTest
    static void testSubmission() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Draft'
        );

        Test.startTest();
        LoanApplicationService.submitApplication(application.Id);
        Test.stopTest();

        Loan_Application__c result = [
            SELECT Application_Status__c,
                   Approval_Stage__c,
                   Monthly_Income_Snapshot__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Submitted', result.Application_Status__c);
        System.assertEquals('Manager Review', result.Approval_Stage__c);
        System.assertEquals(
            Decimal.valueOf('30000'),
            result.Monthly_Income_Snapshot__c
        );
    }

    @IsTest
    static void testCannotSubmitTwice() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Submitted'
        );

        Boolean thrown = false;

        try {
            LoanApplicationService.submitApplication(application.Id);
        } catch (
            LoanApplicationService.InvalidApplicationException ex
        ) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testEligibilityRequiresReviewableStatus() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Draft'
        );

        Boolean thrown = false;

        try {
            LoanApplicationService.assessEligibility(application.Id);
        } catch (
            LoanApplicationService.InvalidApplicationException ex
        ) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testEligibilityRemainsManualReview() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Submitted'
        );

        String result =
            LoanApplicationService.assessEligibility(application.Id);

        System.assertEquals('Manual Review', result);

        Loan_Application__c saved = [
            SELECT Eligibility_Status__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Manual Review', saved.Eligibility_Status__c);
    }

    @IsTest
    static void testAssignedManagerCanStartReview() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Submitted'
        );

        LoanApplicationService.startReview(application.Id);

        Loan_Application__c saved = [
            SELECT Application_Status__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Under Review', saved.Application_Status__c);
    }

    @IsTest
    static void testApprovalAudit() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Under Review'
        );

        application.Eligibility_Status__c = 'Eligible';
        update application;

        Test.startTest();
        LoanApplicationService.approveApplication(application.Id);
        Test.stopTest();

        Loan_Application__c result = [
            SELECT Application_Status__c,
                   Approval_Stage__c,
                   Approved_By__c,
                   Approved_Date__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Approved', result.Application_Status__c);
        System.assertEquals('Decision Complete', result.Approval_Stage__c);
        System.assertEquals(UserInfo.getUserId(), result.Approved_By__c);
        System.assertNotEquals(null, result.Approved_Date__c);
    }

    @IsTest
    static void testRejectionAudit() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Under Review'
        );

        Test.startTest();
        LoanApplicationService.rejectApplication(
            application.Id, 'Other', 'Test rejection comments'
        );
        Test.stopTest();

        Loan_Application__c result = [
            SELECT Application_Status__c,
                   Approval_Stage__c,
                   Rejection_Reason__c,
                   Decision_Comments__c,
                   Rejected_By__c,
                   Rejected_Date__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Rejected', result.Application_Status__c);
        System.assertEquals('Decision Complete', result.Approval_Stage__c);
        System.assertEquals('Other', result.Rejection_Reason__c);
        System.assertEquals(
            'Test rejection comments',
            result.Decision_Comments__c
        );
        System.assertEquals(UserInfo.getUserId(), result.Rejected_By__c);
        System.assertNotEquals(null, result.Rejected_Date__c);
    }

    @IsTest
    static void testRejectionRequiresReason() {
        Boolean thrown = false;

        try {
            LoanApplicationService.rejectApplication(
                null, '', 'Missing reason test'
            );
        } catch (
            LoanApplicationService.InvalidApplicationException ex
        ) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testCannotDecideTwice() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Under Review'
        );

        application.Eligibility_Status__c = 'Eligible';
        update application;

        LoanApplicationService.approveApplication(application.Id);

        Boolean thrown = false;

        try {
            LoanApplicationService.rejectApplication(
                application.Id, 'Other', 'Second decision'
            );
        } catch (
            LoanApplicationService.InvalidApplicationException ex
        ) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testWithdrawal() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        Loan_Application__c application = createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Draft'
        );

        LoanApplicationService.withdrawApplication(application.Id);

        Loan_Application__c saved = [
            SELECT Application_Status__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Withdrawn', saved.Application_Status__c);
    }

    @IsTest
    static void testAssignedApplications() {
        Account customer = createCustomer();
        Contact applicant = createContact(customer.Id);

        createApplication(
            customer.Id, applicant.Id, 25000, 12,
            'Personal', 'Submitted'
        );

        List<Loan_Application__c> results =
            LoanApplicationService.getMyAssignedApplications();

        System.assertEquals(1, results.size());
    }
}