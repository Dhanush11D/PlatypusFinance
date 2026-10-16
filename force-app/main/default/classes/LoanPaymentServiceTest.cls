@IsTest
private class LoanPaymentServiceTest {

    // =========================================================
    // TEST DATA HELPERS
    // =========================================================

    private static Loan__c createActiveLoan() {
        Account customer = new Account(
            Name = 'Platypus Payment Test Customer',
            Customer_Type__c = 'Individual',
            Customer_Status__c = 'Active',
            KYC_Status__c = 'Verified',
            Risk_Category__c = 'Low',
            Customer_Since__c = Date.today()
        );
        insert customer;

        Contact applicant = new Contact(
            FirstName = 'Payment',
            LastName = 'Applicant',
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
                   Outstanding_Balance__c,
                   Total_Amount_Paid__c,
                   Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Id = :loanId
        ];
    }

    private static Id createPendingPayment(
        Id loanId,
        Decimal amount,
        String paymentType
    ) {
        return LoanPaymentService.recordPayment(
            loanId,
            amount,
            Date.today(),
            'UPI',
            paymentType,
            'TEST-TXN-001',
            'Automated test payment'
        );
    }

    // =========================================================
    // RECORD PAYMENT TESTS
    // =========================================================

    @IsTest
    static void testRecordPendingPayment() {
        Loan__c loan = createActiveLoan();

        Test.startTest();

        Id paymentId = createPendingPayment(
            loan.Id,
            5000,
            'Regular Installment'
        );

        Test.stopTest();

        Loan_Payment__c payment =
            LoanPaymentService.getPayment(paymentId);

        System.assertEquals('Pending', payment.Payment_Status__c);
        System.assertEquals(loan.Id, payment.Loan__c);
        System.assertEquals(
            Decimal.valueOf('5000'),
            payment.Payment_Amount__c
        );
        System.assertEquals('UPI', payment.Payment_Method__c);

        Loan__c unchangedLoan = [
            SELECT Outstanding_Balance__c,
                   Total_Amount_Paid__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals(
            Decimal.valueOf('100000'),
            unchangedLoan.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('0'),
            unchangedLoan.Total_Amount_Paid__c
        );
    }

    @IsTest
    static void testRejectInvalidAmount() {
        Loan__c loan = createActiveLoan();

        Boolean thrown = false;

        try {
            createPendingPayment(
                loan.Id,
                0,
                'Regular Installment'
            );
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testRejectFuturePaymentDate() {
        Loan__c loan = createActiveLoan();

        Boolean thrown = false;

        try {
            LoanPaymentService.recordPayment(
                loan.Id,
                1000,
                Date.today().addDays(1),
                'UPI',
                'Regular Installment',
                'FUTURE-TXN',
                'Invalid future payment'
            );
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testRejectInvalidPaymentMethod() {
        Loan__c loan = createActiveLoan();

        Boolean thrown = false;

        try {
            LoanPaymentService.recordPayment(
                loan.Id,
                1000,
                Date.today(),
                'Cryptocurrency',
                'Regular Installment',
                'INVALID-METHOD',
                null
            );
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    // =========================================================
    // SUCCESSFUL PAYMENT TESTS
    // =========================================================

    @IsTest
    static void testSuccessfulPaymentUpdatesLoan() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            5000,
            'Regular Installment'
        );

        Date originalDueDate = loan.Next_Payment_Due_Date__c;

        Test.startTest();
        LoanPaymentService.markPaymentSuccessful(paymentId);
        Test.stopTest();

        Loan_Payment__c payment =
            LoanPaymentService.getPayment(paymentId);

        Loan__c updatedLoan = [
            SELECT Loan_Status__c,
                   Outstanding_Balance__c,
                   Total_Amount_Paid__c,
                   Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals('Successful', payment.Payment_Status__c);
        System.assertEquals('Active', updatedLoan.Loan_Status__c);
        System.assertEquals(
            Decimal.valueOf('95000'),
            updatedLoan.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('5000'),
            updatedLoan.Total_Amount_Paid__c
        );
        System.assertEquals(
            originalDueDate.addMonths(1),
            updatedLoan.Next_Payment_Due_Date__c
        );
    }

    @IsTest
    static void testPendingPaymentDoesNotChangeBalance() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            2500,
            'Part Payment'
        );

        Loan__c beforeProcessing = [
            SELECT Outstanding_Balance__c,
                   Total_Amount_Paid__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals(
            Decimal.valueOf('100000'),
            beforeProcessing.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('0'),
            beforeProcessing.Total_Amount_Paid__c
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Loan__c afterProcessing = [
            SELECT Outstanding_Balance__c,
                   Total_Amount_Paid__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals(
            Decimal.valueOf('97500'),
            afterProcessing.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('2500'),
            afterProcessing.Total_Amount_Paid__c
        );
    }

    @IsTest
    static void testDuplicateSuccessfulProcessingBlocked() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            5000,
            'Part Payment'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Boolean thrown = false;

        try {
            LoanPaymentService.markPaymentSuccessful(paymentId);
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);

        Loan__c updatedLoan = [
            SELECT Outstanding_Balance__c,
                   Total_Amount_Paid__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals(
            Decimal.valueOf('95000'),
            updatedLoan.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('5000'),
            updatedLoan.Total_Amount_Paid__c
        );
    }

    @IsTest
    static void testPaymentCannotExceedBalance() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            150000,
            'Full Settlement'
        );

        Boolean thrown = false;

        try {
            LoanPaymentService.markPaymentSuccessful(paymentId);
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);

        Loan_Payment__c payment =
            LoanPaymentService.getPayment(paymentId);

        System.assertEquals('Pending', payment.Payment_Status__c);
    }

    @IsTest
    static void testFullSettlementClosesLoan() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            100000,
            'Full Settlement'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Loan__c settledLoan = [
            SELECT Loan_Status__c,
                   Outstanding_Balance__c,
                   Total_Amount_Paid__c,
                   Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals('Closed', settledLoan.Loan_Status__c);
        System.assertEquals(
            Decimal.valueOf('0'),
            settledLoan.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('100000'),
            settledLoan.Total_Amount_Paid__c
        );
        System.assertNotEquals(
            null,
            settledLoan.Next_Payment_Due_Date__c
        );
    }

    // =========================================================
    // REVERSAL TESTS
    // =========================================================

    @IsTest
    static void testReverseSuccessfulPayment() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            5000,
            'Part Payment'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Test.startTest();
        LoanPaymentService.reversePayment(
            paymentId,
            'Duplicate transaction'
        );
        Test.stopTest();

        Loan_Payment__c payment =
            LoanPaymentService.getPayment(paymentId);

        Loan__c restoredLoan = [
            SELECT Loan_Status__c,
                   Outstanding_Balance__c,
                   Total_Amount_Paid__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];

        System.assertEquals('Reversed', payment.Payment_Status__c);
        System.assertEquals(
            Decimal.valueOf('100000'),
            restoredLoan.Outstanding_Balance__c
        );
        System.assertEquals(
            Decimal.valueOf('0'),
            restoredLoan.Total_Amount_Paid__c
        );
        System.assertEquals('Active', restoredLoan.Loan_Status__c);
        System.assert(
            payment.Payment_Notes__c.contains(
                'Duplicate transaction'
            )
        );
    }

    @IsTest
    static void testReversePaymentRequiresReason() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            1000,
            'Part Payment'
        );

        LoanPaymentService.markPaymentSuccessful(paymentId);

        Boolean thrown = false;

        try {
            LoanPaymentService.reversePayment(
                paymentId,
                ' '
            );
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @IsTest
    static void testPendingPaymentCannotBeReversed() {
        Loan__c loan = createActiveLoan();

        Id paymentId = createPendingPayment(
            loan.Id,
            1000,
            'Part Payment'
        );

        Boolean thrown = false;

        try {
            LoanPaymentService.reversePayment(
                paymentId,
                'Test reversal'
            );
        } catch (LoanPaymentService.InvalidPaymentException ex) {
            thrown = true;
        }

        System.assert(thrown);
    }

    // =========================================================
    // PAYMENT HISTORY TESTS
    // =========================================================

    @IsTest
    static void testGetLoanPayments() {
        Loan__c loan = createActiveLoan();

        Id firstPaymentId = createPendingPayment(
            loan.Id,
            1000,
            'Part Payment'
        );

        Id secondPaymentId = createPendingPayment(
            loan.Id,
            2000,
            'Regular Installment'
        );

        Loan_Payment__c retrieved =
            LoanPaymentService.getPayment(firstPaymentId);

        System.assertEquals(firstPaymentId, retrieved.Id);

        List<Loan_Payment__c> payments =
            LoanPaymentService.getLoanPayments(loan.Id);

        System.assertEquals(2, payments.size());

        Set<Id> paymentIds = new Set<Id>();

        for (Loan_Payment__c payment : payments) {
            paymentIds.add(payment.Id);
        }

        System.assert(paymentIds.contains(firstPaymentId));
        System.assert(paymentIds.contains(secondPaymentId));
    }
}