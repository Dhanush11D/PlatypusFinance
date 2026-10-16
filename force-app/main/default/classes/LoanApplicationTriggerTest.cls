@IsTest
private class LoanApplicationTriggerTest {

    private static Account createCustomer(String status) {
        Account customer = new Account(
            Name = 'Trigger Test Customer',
            Customer_Status__c = status,
            Customer_Type__c = 'Individual'
        );
        insert customer;
        return customer;
    }

    private static Contact createContact(Id accountId) {
        Contact applicant = new Contact(
            FirstName = 'Test',
            LastName = 'Applicant',
            AccountId = accountId
        );
        insert applicant;
        return applicant;
    }

    private static Loan_Application__c buildApplication(
        Id accountId,
        Id contactId
    ) {
        return new Loan_Application__c(
            Customer_Account__c = accountId,
            Applicant_Contact__c = contactId,
            Application_Date__c = Date.today(),
            Loan_Segment__c = 'Personal',
            Requested_Amount__c = 50000,
            Requested_Tenure_Months__c = 12,
            Purpose_of_Loan__c = 'Personal Expenses',
            Application_Status__c = 'Draft',
            Approval_Stage__c = 'Not Started',
            Eligibility_Status__c = 'Not Checked'
        );
    }

    @IsTest
    static void testValidDraftCanBeCreated() {
        Account customer = createCustomer('Active');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);

        Test.startTest();
        insert application;
        Test.stopTest();

        System.assertNotEquals(null, application.Id);

        Loan_Application__c saved = [
            SELECT Application_Status__c,
                   Requested_Amount__c,
                   Requested_Tenure_Months__c,
                   Eligibility_Status__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Draft', saved.Application_Status__c);
        System.assertEquals(
            Decimal.valueOf('50000'),
            saved.Requested_Amount__c
        );
        System.assertEquals(
            Decimal.valueOf('12'),
            saved.Requested_Tenure_Months__c
        );
        System.assertEquals(
            'Not Checked',
            saved.Eligibility_Status__c
        );
    }

    @IsTest
    static void testRejectAmountBelowMinimum() {
        Account customer = createCustomer('Active');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        application.Requested_Amount__c = 9999;

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains(
                'between ₹10,000 and ₹5,00,000'
            )
        );
    }

    @IsTest
    static void testRejectAmountAboveMaximum() {
        Account customer = createCustomer('Active');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        application.Requested_Amount__c = 500001;

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectTenureBelowMinimum() {
        Account customer = createCustomer('Active');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        application.Requested_Tenure_Months__c = 2;

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectTenureAboveMaximum() {
        Account customer = createCustomer('Active');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        application.Requested_Tenure_Months__c = 54;

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectContactFromDifferentAccount() {
        Account firstCustomer = createCustomer('Active');
        Account secondCustomer = createCustomer('Active');
        Contact applicant = createContact(secondCustomer.Id);

        Loan_Application__c application =
            buildApplication(firstCustomer.Id, applicant.Id);

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains(
                'must belong to the selected Customer Account'
            )
        );
    }

    @IsTest
    static void testRejectSubmissionForBlockedCustomer() {
        Account customer = createCustomer('Blocked');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        application.Application_Status__c = 'Submitted';

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectSubmissionWithoutRequiredData() {
        Loan_Application__c application = new Loan_Application__c(
            Application_Status__c = 'Submitted',
            Eligibility_Status__c = 'Not Checked',
            Approval_Stage__c = 'Not Started'
        );

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectUpdateToInvalidAmount() {
        Account customer = createCustomer('Active');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        insert application;

        application.Requested_Amount__c = 9000;

        Test.startTest();
        Database.SaveResult result = Database.update(application, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());

        Loan_Application__c unchanged = [
            SELECT Requested_Amount__c
            FROM Loan_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals(
            Decimal.valueOf('50000'),
            unchanged.Requested_Amount__c
        );
    }

    @IsTest
    static void testInactiveCustomerCannotProceed() {
        Account customer = createCustomer('Inactive');
        Contact applicant = createContact(customer.Id);
        Loan_Application__c application =
            buildApplication(customer.Id, applicant.Id);
        application.Application_Status__c = 'Submitted';

        Database.SaveResult result = Database.insert(application, false);

        System.assertEquals(false, result.isSuccess());
    }
}