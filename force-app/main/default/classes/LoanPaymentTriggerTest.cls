@IsTest
private class LoanPaymentTriggerTest {

    private static Id createActiveLoan() {
        Account customer = new Account(
            Name = 'Payment Trigger Customer',
            Customer_Type__c = 'Individual',
            Customer_Status__c = 'Active',
            KYC_Status__c = 'Verified',
            Risk_Category__c = 'Low',
            Customer_Since__c = Date.today()
        );
        insert customer;

        Contact applicant = new Contact(
            FirstName = 'Payment',
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

        return LoanService.disburseApprovedApplication(
            application.Id,
            Date.today()
        );
    }

    private static Loan_Payment__c buildPendingPayment(Id loanId) {
        return new Loan_Payment__c(
            Loan__c = loanId,
            Received_By__c = UserInfo.getUserId(),
            Payment_Date__c = Date.today(),
            Payment_Amount__c = 5000,
            Payment_Method__c = 'UPI',
            Payment_Type__c = 'Regular Installment',
            Payment_Status__c = 'Pending',
            Transaction_Reference__c = 'TRIGGER-TEST-001',
            Payment_Notes__c = 'Trigger test payment'
        );
    }

    @IsTest
    static void testValidPendingPaymentInsert() {
        Id loanId = createActiveLoan();
        Loan_Payment__c payment = buildPendingPayment(loanId);

        Test.startTest();
        insert payment;
        Test.stopTest();

        System.assertNotEquals(null, payment.Id);

        Loan_Payment__c savedPayment = [
            SELECT Payment_Status__c,
                   Payment_Amount__c,
                   Loan__c
            FROM Loan_Payment__c
            WHERE Id = :payment.Id
        ];

        System.assertEquals('Pending', savedPayment.Payment_Status__c);
        System.assertEquals(
            Decimal.valueOf('5000'),
            savedPayment.Payment_Amount__c
        );
        System.assertEquals(loanId, savedPayment.Loan__c);
    }

    @IsTest
    static void testRejectZeroAmount() {
        Id loanId = createActiveLoan();
        Loan_Payment__c payment = buildPendingPayment(loanId);
        payment.Payment_Amount__c = 0;

        Database.SaveResult result = Database.insert(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectNegativeAmount() {
        Id loanId = createActiveLoan();
        Loan_Payment__c payment = buildPendingPayment(loanId);
        payment.Payment_Amount__c = -100;

        Database.SaveResult result = Database.insert(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectFuturePaymentDate() {
        Id loanId = createActiveLoan();
        Loan_Payment__c payment = buildPendingPayment(loanId);
        payment.Payment_Date__c = Date.today().addDays(1);

        Database.SaveResult result = Database.insert(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectDirectSuccessfulInsert() {
        Id loanId = createActiveLoan();
        Loan_Payment__c payment = buildPendingPayment(loanId);
        payment.Payment_Status__c = 'Successful';

        Database.SaveResult result = Database.insert(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectChangingSuccessfulPaymentAmount() {
        Id loanId = createActiveLoan();

        Id paymentId = LoanPaymentService.recordPayment(
            loanId,
            5000,
            Date.today(),
            'UPI',
            'Regular Installment',
            'TRIGGER-AMOUNT-001',
            'Amount protection test'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Loan_Payment__c payment = [
            SELECT Id, Payment_Amount__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
        ];
        payment.Payment_Amount__c = 6000;

        Database.SaveResult result = Database.update(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectChangingSuccessfulPaymentLoan() {
        Id firstLoanId = createActiveLoan();
        Id secondLoanId = createActiveLoan();

        Id paymentId = LoanPaymentService.recordPayment(
            firstLoanId,
            1000,
            Date.today(),
            'UPI',
            'Part Payment',
            'TRIGGER-LOAN-001',
            'Loan protection test'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Loan_Payment__c payment = [
            SELECT Id, Loan__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
        ];
        payment.Loan__c = secondLoanId;

        Database.SaveResult result = Database.update(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testRejectReactivatingReversedPayment() {
        Id loanId = createActiveLoan();

        Id paymentId = LoanPaymentService.recordPayment(
            loanId,
            1000,
            Date.today(),
            'UPI',
            'Part Payment',
            'TRIGGER-REVERSE-001',
            'Reversal test'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);
        LoanPaymentService.reversePayment(
            paymentId,
            'Test reversal'
        );

        Loan_Payment__c payment = [
            SELECT Id, Payment_Status__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
        ];
        payment.Payment_Status__c = 'Successful';

        Database.SaveResult result = Database.update(payment, false);

        System.assertEquals(false, result.isSuccess());
    }

    @IsTest
    static void testSuccessfulPaymentCanBeReversedByService() {
        Id loanId = createActiveLoan();

        Id paymentId = LoanPaymentService.recordPayment(
            loanId,
            1000,
            Date.today(),
            'UPI',
            'Part Payment',
            'TRIGGER-SERVICE-REVERSAL',
            'Service reversal test'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Test.startTest();
        LoanPaymentService.reversePayment(
            paymentId,
            'Verified reversal'
        );
        Test.stopTest();

        Loan_Payment__c payment = [
            SELECT Payment_Status__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
        ];

        System.assertEquals('Reversed', payment.Payment_Status__c);
    }

    @IsTest
    static void testRejectMissingRequiredFields() {
        Id loanId = createActiveLoan();

        // Missing Loan__c
        Loan_Payment__c p1 = buildPendingPayment(loanId);
        p1.Loan__c = null;
        System.assertEquals(false, Database.insert(p1, false).isSuccess());

        // Missing Amount
        Loan_Payment__c p2 = buildPendingPayment(loanId);
        p2.Payment_Amount__c = null;
        System.assertEquals(false, Database.insert(p2, false).isSuccess());

        // Missing Date
        Loan_Payment__c p3 = buildPendingPayment(loanId);
        p3.Payment_Date__c = null;
        System.assertEquals(false, Database.insert(p3, false).isSuccess());

        // Missing Method
        Loan_Payment__c p4 = buildPendingPayment(loanId);
        p4.Payment_Method__c = null;
        System.assertEquals(false, Database.insert(p4, false).isSuccess());

        // Missing Type
        Loan_Payment__c p5 = buildPendingPayment(loanId);
        p5.Payment_Type__c = null;
        System.assertEquals(false, Database.insert(p5, false).isSuccess());

        // Missing Status
        Loan_Payment__c p6 = buildPendingPayment(loanId);
        p6.Payment_Status__c = null;
        System.assertEquals(false, Database.insert(p6, false).isSuccess());
    }

    @IsTest
    static void testRejectModifyingSuccessfulPaymentDetails() {
        Id loanId = createActiveLoan();
        Id paymentId = LoanPaymentService.recordPayment(
            loanId, 1000, Date.today(), 'UPI', 'Part Payment', 'REF-MOD-1', 'Notes'
        );
        LoanPaymentService.markPaymentSuccessful(paymentId);

        Loan_Payment__c payment = [
            SELECT Id, Payment_Date__c, Payment_Method__c, Payment_Type__c, Payment_Status__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
        ];

        // Change Date
        payment.Payment_Date__c = Date.today().addDays(-1);
        System.assertEquals(false, Database.update(payment, false).isSuccess());

        // Reset and change Method
        payment = [SELECT Id, Payment_Date__c, Payment_Method__c, Payment_Type__c, Payment_Status__c FROM Loan_Payment__c WHERE Id = :paymentId];
        payment.Payment_Method__c = 'Cash';
        System.assertEquals(false, Database.update(payment, false).isSuccess());

        // Reset and change Type
        payment = [SELECT Id, Payment_Date__c, Payment_Method__c, Payment_Type__c, Payment_Status__c FROM Loan_Payment__c WHERE Id = :paymentId];
        payment.Payment_Type__c = 'Full Settlement';
        System.assertEquals(false, Database.update(payment, false).isSuccess());

        // Reset and change Status to Pending
        payment = [SELECT Id, Payment_Date__c, Payment_Method__c, Payment_Type__c, Payment_Status__c FROM Loan_Payment__c WHERE Id = :paymentId];
        payment.Payment_Status__c = 'Pending';
        System.assertEquals(false, Database.update(payment, false).isSuccess());
    }

    @IsTest
    static void testRejectModifyingReversedPaymentDetails() {
        Id loanId = createActiveLoan();
        Id paymentId = LoanPaymentService.recordPayment(
            loanId, 1000, Date.today(), 'UPI', 'Part Payment', 'REF-REV-MOD', 'Notes'
        );
        LoanPaymentService.markPaymentSuccessful(paymentId);
        LoanPaymentService.reversePayment(paymentId, 'Reason');

        Loan_Payment__c payment = [
            SELECT Id, Payment_Amount__c, Payment_Method__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
        ];
        payment.Payment_Amount__c = 2000;
        System.assertEquals(false, Database.update(payment, false).isSuccess());
    }

    @IsTest
    static void testRejectReactivatingFailedPayment() {
        Id loanId = createActiveLoan();
        Loan_Payment__c payment = buildPendingPayment(loanId);
        insert payment;

        payment.Payment_Status__c = 'Failed';
        update payment;

        payment.Payment_Status__c = 'Pending';
        System.assertEquals(false, Database.update(payment, false).isSuccess());
    }
}