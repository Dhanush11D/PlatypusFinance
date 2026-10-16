@IsTest
private class PFLoanOfficerDashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        Account customer = new Account(
            Name = 'Platypus Test Customer',
            Customer_Type__c = 'Individual',
            Customer_Status__c = 'Active',
            KYC_Status__c = 'Verified',
            Risk_Category__c = 'Low',
            Customer_Since__c = Date.today()
        );
        insert customer;

        Contact applicant = new Contact(
            FirstName = 'Test',
            LastName = 'Applicant',
            AccountId = customer.Id,
            Email = 'applicant@example.com'
        );
        insert applicant;

        List<Loan_Application__c> applications =
            new List<Loan_Application__c>();

        applications.add(createApplication(
            customer.Id, applicant.Id, 'Draft', 10000
        ));
        applications.add(createApplication(
            customer.Id, applicant.Id, 'Submitted', 20000
        ));
        applications.add(createApplication(
            customer.Id, applicant.Id, 'Under Review', 30000
        ));
        applications.add(createApplication(
            customer.Id, applicant.Id, 'Approved', 40000
        ));
        applications.add(createApplication(
            customer.Id, applicant.Id, 'Rejected', 50000
        ));

        insert applications;
    }

    private static Loan_Application__c createApplication(
        Id accountId,
        Id contactId,
        String status,
        Decimal amount
    ) {
        return new Loan_Application__c(
            Customer_Account__c = accountId,
            Applicant_Contact__c = contactId,
            Application_Date__c = Date.today(),
            Loan_Segment__c = 'Personal',
            Requested_Amount__c = amount,
            Requested_Tenure_Months__c = 12,
            Purpose_of_Loan__c = 'Medical',
            Application_Status__c = status,
            Approval_Stage__c = status == 'Approved' ||
                status == 'Rejected'
                ? 'Decision Complete'
                : 'Not Started',
            Eligibility_Status__c = 'Not Checked'
        );
    }

    @IsTest
    static void testGetDashboardMetrics() {
        Test.startTest();
        PFLoanOfficerDashboardController.DashboardMetrics metrics =
            PFLoanOfficerDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertEquals(5, metrics.totalApplications);
        System.assertEquals(2, metrics.pendingReview);
        System.assertEquals(1, metrics.approvedApplications);
        System.assertEquals(1, metrics.rejectedApplications);
        System.assertEquals(
            Decimal.valueOf('150000'),
            metrics.totalRequestedAmount
        );
    }

    @IsTest
    static void testGetRecentApplications() {
        Test.startTest();
        List<PFLoanOfficerDashboardController.ApplicationRow> rows =
            PFLoanOfficerDashboardController.getRecentApplications();
        Test.stopTest();

        System.assertEquals(5, rows.size());

        for (PFLoanOfficerDashboardController.ApplicationRow row : rows) {
            System.assertNotEquals(null, row.id);
            System.assertNotEquals(null, row.applicationNumber);
            System.assertEquals('Platypus Test Customer', row.customerName);
            System.assertEquals('Personal', row.segment);
            System.assertNotEquals(null, row.requestedAmount);
            System.assertNotEquals(null, row.status);
            System.assertEquals(Date.today(), row.applicationDate);
        }
    }

    @IsTest
    static void testRecentApplicationsLimit() {
        List<Loan_Application__c> extraApplications =
            new List<Loan_Application__c>();

        Account customer = [
            SELECT Id
            FROM Account
            WHERE Name = 'Platypus Test Customer'
            LIMIT 1
        ];

        Contact applicant = [
            SELECT Id
            FROM Contact
            WHERE AccountId = :customer.Id
            LIMIT 1
        ];

        for (Integer i = 0; i < 7; i++) {
            extraApplications.add(createApplication(
                customer.Id,
                applicant.Id,
                'Draft',
                10000 + i
            ));
        }

        insert extraApplications;

        Test.startTest();
        List<PFLoanOfficerDashboardController.ApplicationRow> rows =
            PFLoanOfficerDashboardController.getRecentApplications();
        Test.stopTest();

        System.assertEquals(
            10,
            rows.size(),
            'The dashboard should return no more than ten applications.'
        );
    }
}