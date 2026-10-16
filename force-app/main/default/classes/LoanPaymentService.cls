public with sharing class LoanPaymentService {

    public class InvalidPaymentException extends Exception {}
    public class PaymentAuthorizationException extends Exception {}

    public static Boolean isServiceProcessing = false;

    private static final Set<String> VALID_METHODS =
        new Set<String>{
            'Cash', 'UPI', 'Bank Transfer',
            'Card', 'Cheque', 'Other'
        };

    private static final Set<String> VALID_TYPES =
        new Set<String>{
            'Regular Installment', 'Part Payment',
            'Full Settlement', 'Penalty', 'Other'
        };

    // =========================================================
    // RECORD A PENDING PAYMENT
    // Recording a payment does not change the loan balance.
    // =========================================================

    @AuraEnabled
    public static Id recordPayment(
        Id loanId,
        Decimal amount,
        Date paymentDate,
        String paymentMethod,
        String paymentType,
        String transactionReference,
        String paymentNotes
    ) {
        if (loanId == null) {
            throw new InvalidPaymentException(
                'A Loan ID is required.'
            );
        }

        if (amount == null || amount <= 0) {
            throw new InvalidPaymentException(
                'Payment amount must be greater than zero.'
            );
        }

        if (paymentDate == null || paymentDate > Date.today()) {
            throw new InvalidPaymentException(
                'Enter a valid payment date that is not in the future.'
            );
        }

        if (String.isBlank(paymentMethod) ||
            !VALID_METHODS.contains(paymentMethod)) {
            throw new InvalidPaymentException(
                'Select a valid payment method.'
            );
        }

        if (String.isBlank(paymentType) ||
            !VALID_TYPES.contains(paymentType)) {
            throw new InvalidPaymentException(
                'Select a valid payment type.'
            );
        }

        Loan__c loan = getLoanForUpdate(loanId);

        if (loan.Loan_Status__c != 'Active') {
            throw new InvalidPaymentException(
                'Payments can only be recorded against Active loans.'
            );
        }

        if (loan.Outstanding_Balance__c == null ||
            loan.Outstanding_Balance__c <= 0) {
            throw new InvalidPaymentException(
                'This loan has no outstanding balance.'
            );
        }

        Loan_Payment__c payment = new Loan_Payment__c(
            Loan__c = loan.Id,
            Received_By__c = UserInfo.getUserId(),
            Payment_Date__c = paymentDate,
            Payment_Amount__c = amount,
            Payment_Method__c = paymentMethod,
            Payment_Type__c = paymentType,
            Payment_Status__c = 'Pending',
            Transaction_Reference__c = transactionReference,
            Payment_Notes__c = paymentNotes
        );

        insert payment;
        return payment.Id;
    }

    // =========================================================
    // PROCESS A PENDING PAYMENT AS SUCCESSFUL
    // Only this method updates financial totals.
    // =========================================================

    @AuraEnabled
    public static void markPaymentSuccessful(Id paymentId) {
        if (paymentId == null) {
            throw new InvalidPaymentException(
                'A Payment ID is required.'
            );
        }

        Loan_Payment__c payment = getPaymentForUpdate(paymentId);

        if (payment.Payment_Status__c != 'Pending') {
            throw new InvalidPaymentException(
                'Only Pending payments can be marked Successful.'
            );
        }

        if (payment.Loan__c == null ||
            payment.Payment_Amount__c == null ||
            payment.Payment_Amount__c <= 0) {
            throw new InvalidPaymentException(
                'The payment is missing a valid loan or amount.'
            );
        }

        Loan__c loan = getLoanForUpdate(payment.Loan__c);

        if (loan.Loan_Status__c != 'Active') {
            throw new InvalidPaymentException(
                'Payments can only be processed for Active loans.'
            );
        }

        if (loan.Outstanding_Balance__c == null ||
            loan.Outstanding_Balance__c <= 0) {
            throw new InvalidPaymentException(
                'The loan has no outstanding balance.'
            );
        }

        if (payment.Payment_Amount__c > loan.Outstanding_Balance__c) {
            throw new InvalidPaymentException(
                'Payment exceeds the outstanding balance. Use the approved settlement process.'
            );
        }

        Decimal existingTotal = loan.Total_Amount_Paid__c == null
            ? 0
            : loan.Total_Amount_Paid__c;

        Decimal newTotalPaid =
            existingTotal + payment.Payment_Amount__c;

        Decimal newOutstanding =
            loan.Outstanding_Balance__c - payment.Payment_Amount__c;

        if (newOutstanding < 0) {
            newOutstanding = 0;
        }

        loan.Total_Amount_Paid__c =
            newTotalPaid.setScale(2, RoundingMode.HALF_UP);

        loan.Outstanding_Balance__c =
            newOutstanding.setScale(2, RoundingMode.HALF_UP);

        // Do not clear Next_Payment_Due_Date__c because it is required.
        if (newOutstanding == 0) {
            loan.Loan_Status__c = 'Closed';
        } else if (payment.Payment_Type__c == 'Regular Installment' &&
                   loan.Next_Payment_Due_Date__c != null) {
            loan.Next_Payment_Due_Date__c =
                loan.Next_Payment_Due_Date__c.addMonths(1);
        }

        payment.Payment_Status__c = 'Successful';

        isServiceProcessing = true;
        try {
            update loan;
            update payment;
        } finally {
            isServiceProcessing = false;
        }
    }

    // =========================================================
    // REVERSE A SUCCESSFUL PAYMENT
    // Restores the balance and removes the payment from totals.
    // =========================================================

    @AuraEnabled
    public static void reversePayment(
        Id paymentId,
        String reversalReason
    ) {
        if (paymentId == null) {
            throw new InvalidPaymentException(
                'A Payment ID is required.'
            );
        }

        if (String.isBlank(reversalReason)) {
            throw new InvalidPaymentException(
                'A reason is required to reverse a payment.'
            );
        }

        Loan_Payment__c payment = getPaymentForUpdate(paymentId);

        if (payment.Payment_Status__c != 'Successful') {
            throw new InvalidPaymentException(
                'Only Successful payments can be reversed.'
            );
        }

        Loan__c loan = getLoanForUpdate(payment.Loan__c);

        Decimal paymentAmount = payment.Payment_Amount__c;

        Decimal existingTotal = loan.Total_Amount_Paid__c == null
            ? 0
            : loan.Total_Amount_Paid__c;

        Decimal existingOutstanding =
            loan.Outstanding_Balance__c == null
                ? 0
                : loan.Outstanding_Balance__c;

        Decimal restoredOutstanding =
            existingOutstanding + paymentAmount;

        Decimal restoredTotal =
            existingTotal - paymentAmount;

        if (restoredTotal < 0) {
            throw new InvalidPaymentException(
                'Payment totals are inconsistent. Reversal was not processed.'
            );
        }

        loan.Outstanding_Balance__c =
            restoredOutstanding.setScale(2, RoundingMode.HALF_UP);

        loan.Total_Amount_Paid__c =
            restoredTotal.setScale(2, RoundingMode.HALF_UP);

        // A reversed payment may reopen a previously settled loan.
        if (loan.Loan_Status__c == 'Closed' &&
            restoredOutstanding > 0) {
            loan.Loan_Status__c = 'Active';
        }

        payment.Payment_Status__c = 'Reversed';

        String existingNotes = payment.Payment_Notes__c;

        String reversalNote =
            'Reversal reason: ' + reversalReason.trim();

        if (String.isBlank(existingNotes)) {
            payment.Payment_Notes__c = reversalNote;
        } else {
            payment.Payment_Notes__c =
                existingNotes + '\n' + reversalNote;
        }

        isServiceProcessing = true;
        try {
            update loan;
            update payment;
        } finally {
            isServiceProcessing = false;
        }
    }

    // =========================================================
    // RETRIEVE A PAYMENT
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static Loan_Payment__c getPayment(Id paymentId) {
        if (paymentId == null) {
            throw new InvalidPaymentException(
                'A Payment ID is required.'
            );
        }

        List<Loan_Payment__c> payments = [
            SELECT Id,
                   Name,
                   Loan__c,
                   Received_By__c,
                   Payment_Date__c,
                   Payment_Amount__c,
                   Payment_Method__c,
                   Payment_Status__c,
                   Payment_Type__c,
                   Transaction_Reference__c,
                   Payment_Notes__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
            LIMIT 1
        ];

        if (payments.isEmpty()) {
            throw new InvalidPaymentException(
                'Payment not found or not accessible.'
            );
        }

        return payments[0];
    }

    // =========================================================
    // GET PAYMENTS FOR A LOAN
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<Loan_Payment__c> getLoanPayments(Id loanId) {
        if (loanId == null) {
            throw new InvalidPaymentException(
                'A Loan ID is required.'
            );
        }

        return [
            SELECT Id,
                   Name,
                   Loan__c,
                   Received_By__c,
                   Payment_Date__c,
                   Payment_Amount__c,
                   Payment_Method__c,
                   Payment_Status__c,
                   Payment_Type__c,
                   Transaction_Reference__c,
                   Payment_Notes__c
            FROM Loan_Payment__c
            WHERE Loan__c = :loanId
            ORDER BY Payment_Date__c DESC, CreatedDate DESC
            LIMIT 200
        ];
    }

    // =========================================================
    // SEARCH ACTIVE LOANS (FOR CASHIER SERVICING)
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<Loan__c> searchActiveLoans(String searchTerm) {
        String filterPattern = '%' + (String.isBlank(searchTerm) ? '' : searchTerm.trim()) + '%';
        return [
            SELECT Id, Name, Customer_Account__c, Customer_Account__r.Name,
                   Borrower_Contact__c, Borrower_Contact__r.Name,
                   Principal_Amount__c, Annual_Interest_Rate__c,
                   Tenure_Months__c, Loan_Status__c, Monthly_Installment__c,
                   Outstanding_Balance__c, Total_Amount_Paid__c,
                   Next_Payment_Due_Date__c, Disbursement_Date__c
            FROM Loan__c
            WHERE Loan_Status__c = 'Active'
              AND (Name LIKE :filterPattern
                   OR Customer_Account__r.Name LIKE :filterPattern
                   OR Borrower_Contact__r.Name LIKE :filterPattern)
            ORDER BY Name ASC
            LIMIT 50
        ];
    }

    // =========================================================
    // PRIVATE HELPERS
    // =========================================================

    private static Loan__c getLoanForUpdate(Id loanId) {
        List<Loan__c> loans = [
            SELECT Id,
                   Loan_Status__c,
                   Outstanding_Balance__c,
                   Total_Amount_Paid__c,
                   Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Id = :loanId
            LIMIT 1
            FOR UPDATE
        ];

        if (loans.isEmpty()) {
            throw new InvalidPaymentException(
                'Loan not found or not accessible.'
            );
        }

        return loans[0];
    }

    private static Loan_Payment__c getPaymentForUpdate(
        Id paymentId
    ) {
        List<Loan_Payment__c> payments = [
            SELECT Id,
                   Loan__c,
                   Payment_Amount__c,
                   Payment_Status__c,
                   Payment_Type__c,
                   Payment_Notes__c
            FROM Loan_Payment__c
            WHERE Id = :paymentId
            LIMIT 1
            FOR UPDATE
        ];

        if (payments.isEmpty()) {
            throw new InvalidPaymentException(
                'Payment not found or not accessible.'
            );
        }

        return payments[0];
    }
}