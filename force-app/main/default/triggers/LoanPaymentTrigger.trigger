trigger LoanPaymentTrigger on Loan_Payment__c (
    before insert,
    before update
) {
    for (Loan_Payment__c payment : Trigger.new) {

        // Validate payment amount.
        if (payment.Payment_Amount__c != null &&
            payment.Payment_Amount__c <= 0) {
            payment.Payment_Amount__c.addError(
                'Payment amount must be greater than zero.'
            );
        }

        // Validate payment date.
        if (payment.Payment_Date__c != null &&
            payment.Payment_Date__c > Date.today()) {
            payment.Payment_Date__c.addError(
                'Payment date cannot be in the future.'
            );
        }

        // Validate required payment details.
        if (payment.Loan__c == null) {
            payment.Loan__c.addError(
                'A Loan must be selected for every payment.'
            );
        }

        if (payment.Payment_Amount__c == null) {
            payment.Payment_Amount__c.addError(
                'Payment amount is required.'
            );
        }

        if (payment.Payment_Date__c == null) {
            payment.Payment_Date__c.addError(
                'Payment date is required.'
            );
        }

        if (String.isBlank(payment.Payment_Method__c)) {
            payment.Payment_Method__c.addError(
                'Payment method is required.'
            );
        }

        if (String.isBlank(payment.Payment_Type__c)) {
            payment.Payment_Type__c.addError(
                'Payment type is required.'
            );
        }

        if (String.isBlank(payment.Payment_Status__c)) {
            payment.Payment_Status__c.addError(
                'Payment status is required.'
            );
        }

        if (Trigger.isInsert) {
            // Payments must begin as Pending.
            if (payment.Payment_Status__c != 'Pending') {
                payment.Payment_Status__c.addError(
                    'New payments must begin with Pending status.'
                );
            }
        }

        if (Trigger.isUpdate) {
            Loan_Payment__c oldPayment =
                Trigger.oldMap.get(payment.Id);

            // Prevent changing the payment's financial identity
            // after it has been successfully processed.
            if (oldPayment.Payment_Status__c == 'Successful') {
                if (payment.Loan__c != oldPayment.Loan__c) {
                    payment.Loan__c.addError(
                        'The Loan cannot be changed after successful processing.'
                    );
                }

                if (payment.Payment_Amount__c !=
                    oldPayment.Payment_Amount__c) {
                    payment.Payment_Amount__c.addError(
                        'The amount cannot be changed after successful processing.'
                    );
                }

                if (payment.Payment_Date__c !=
                    oldPayment.Payment_Date__c) {
                    payment.Payment_Date__c.addError(
                        'The payment date cannot be changed after successful processing.'
                    );
                }

                if (payment.Payment_Method__c !=
                    oldPayment.Payment_Method__c) {
                    payment.Payment_Method__c.addError(
                        'The payment method cannot be changed after successful processing.'
                    );
                }

                if (payment.Payment_Type__c !=
                    oldPayment.Payment_Type__c) {
                    payment.Payment_Type__c.addError(
                        'The payment type cannot be changed after successful processing.'
                    );
                }

                // A successful payment may only be reversed.
                if (payment.Payment_Status__c != 'Successful' &&
                    payment.Payment_Status__c != 'Reversed') {
                    payment.Payment_Status__c.addError(
                        'A successful payment can only remain Successful or become Reversed.'
                    );
                }
            }

            // Prevent a reversed payment from being reused.
            if (oldPayment.Payment_Status__c == 'Reversed' &&
                payment.Payment_Status__c != 'Reversed') {
                payment.Payment_Status__c.addError(
                    'A reversed payment cannot be reactivated.'
                );
            }

            // Prevent failed payments from being marked successful
            // without creating a new payment record.
            if (oldPayment.Payment_Status__c == 'Failed' &&
                payment.Payment_Status__c != 'Failed') {
                payment.Payment_Status__c.addError(
                    'A failed payment cannot be reactivated. Record a new payment instead.'
                );
            }
        }
    }
}